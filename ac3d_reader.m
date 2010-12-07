/* ======================================================================
 * AC3D reader lib for iPhone
 * See license.txt (BSD license)
 * Author: Edward Patel/Memention AB
 * ====================================================================== */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <sys/sysctl.h>

#include <TargetConditionals.h>

static int __unused is_iPhone3GS = 0;

#if TARGET_IPHONE_SIMULATOR
static int tris;
static int strips;
static int strips_pts;
#  define INIT_STATS tris = strips = strips_pts = 0
#  define ADD_TRIS(_v) tris += _v
#  define ADD_STRIPS(_v) strips += _v
#  define ADD_STRIPS_PTS(_v) strips_pts += _v
#  define SHOW_STATS NSLog(@"\nTris: %d\nCreated tri strips: %d\nPoints removed: %d", tris, strips, strips_pts)
#else
#  define INIT_STATS 
#  define ADD_TRIS(_v) 
#  define ADD_STRIPS(_v) 
#  define ADD_STRIPS_PTS(_v) 
#  define SHOW_STATS
#endif

//#define USE_VBO
#define USE_FLOATS

#import "AC3DTexture.h"

#include "ac3d_reader.h"

static NSMutableDictionary *textures = nil;
static int lastMat = -1;

static
void load_textures_ac3d_object(AC3DObject *obj, 
                               NSMutableDictionary *textures);

static
void init_ac3d_textures()
{
    if (!textures) {
#if TARGET_IPHONE_SIMULATOR
        /* empty */
#else
        char machine[32];
        size_t len=32;
        sysctlbyname("hw.machine", machine, &len, NULL, 0);
        if (!strcmp(machine, "iPhone2,1")) 
            is_iPhone3GS = 1;
#endif
        textures = [[NSMutableDictionary alloc] init];
    }
}

void free_ac3d_textures()
{
    if (textures)
        [textures release];
    textures = nil;
}

enum {
    SURF_SHADED     = 0x10,
    SURF_TWOSIDED   = 0x20,
    SURF_POLYGON    = 0, // USING FAN
    SURF_CLOSEDLINE = 1,
    SURF_LINE       = 2,
    SURF_TRI_STRIP  = 3,
    OBJECT_WORLD    = 0,
    OBJECT_POLY,
    OBJECT_GROUP,
    OBJECT_LIGHT
};

struct AC3DFile_s;
struct AC3DMaterial_s;
struct AC3DObject_s;
struct AC3DSurf_s;

struct AC3DFile_s {
    int                     nummats;
    float                  *bbox;
    struct AC3DMaterial_s **mats;
    struct AC3DObject_s    *obj;
};

struct AC3DMaterial_s {
    char  *name;
    float  rgb[4];
    float  amb[4];
    float  emis[4];
    float  spec[4];
    float  shi;
};

typedef float AC3DVert[6]; // pos+normal

typedef union {
    float f;
    int   i;
    short cmd[2];
    struct {
        unsigned char params[4];
    } b;
} AC3Doptcmd;

struct AC3DObject_s {
    bool                   texture_loaded;
    bool                   enabled;
    int                    type;
    char                  *name;
    char                  *texture;
    int                    texid;
    float                 *texrep; // 2
    float                 *texoff; // 2
    float                 *rot;    // 9
    float                 *loc;    // 3
    float                  angle;
    float                 *rotvec; // 6
    float                 *bbox;   // 6
    int                    numvert;
    AC3DVert              *verts;
    int                    numcmds;
    AC3Doptcmd            *optcmds;
    GLuint                 vbo;
    int                    numsurf;
    struct AC3DSurf_s    **surfs;
    int                    numkids;
    struct AC3DObject_s  **kids;
    // data - not implemented
    // url - not implemented
};

struct AC3Dtexref_s {
    float texu;
    float texv;
};

struct AC3DSurf_s {
    int                  type;
    int                  mat;
    float                normal[3];
    int                  numrefs;
    short               *vrefs;
    struct AC3Dtexref_s *texrefs;
};

typedef struct AC3DMaterial_s AC3DMaterial;
typedef struct AC3DSurf_s     AC3DSurf;
typedef struct AC3Dtexref_s   AC3Dtexref;

// ----------------------------------------------------------------------

#define CATCH_ERROR catch_error
#define THROW( _str ) do { *err = _str ; goto catch_error; } while (0)

// ----------------------------------------------------------------------

static
void free_ac3d_material(AC3DMaterial *mat)
{
    if (mat) {
        if (mat->name)
            free(mat->name);
        free(mat);
    }
}

static
void free_ac3d_surf(AC3DSurf *surf)
{
    if (surf) {
        if (surf->vrefs) 
            free(surf->vrefs);
        if (surf->texrefs) 
            free(surf->texrefs);
        free(surf);
    }
}

static
void free_ac3d_object(AC3DObject *obj)
{
    if (obj) {
        int i;
#ifdef USE_VBO
        if (obj->vbo)
            glDeleteBuffers(1, &obj->vbo);
#endif
        if (obj->name)
            free(obj->name);
        if (obj->texture)
            free(obj->texture);
        if (obj->texrep)
            free(obj->texrep);
        if (obj->texoff)
            free(obj->texoff);
        if (obj->rot)
            free(obj->rot);
        if (obj->rotvec)
            free(obj->rotvec);
        if (obj->bbox)
            free(obj->bbox);
        if (obj->loc)
            free(obj->loc);
        if (obj->numvert > 0 && obj->verts) 
            free(obj->verts);
        if (obj->numcmds > 0 && obj->optcmds) 
            free(obj->optcmds);
        if (obj->numsurf > 0 && obj->surfs) {
            for (i=0; i<obj->numsurf; i++) {
                if (obj->surfs[i])
                    free_ac3d_surf(obj->surfs[i]);
            }
            free(obj->surfs);
        }
        if (obj->numkids > 0 && obj->kids) {
            for (i=0; i<obj->numkids; i++) {
                if (obj->kids[i])
                    free_ac3d_object(obj->kids[i]);
            }
            free(obj->kids);
        }
        free(obj);
    }
}

void free_ac3d_file(AC3DFile *file)
{
    if (file) {
        if (file->obj)
            free_ac3d_object(file->obj);
        if (file->nummats && file->mats) {
            int i;
            for (i=0; i<file->nummats; i++) {
                free_ac3d_material(file->mats[i]);
            }
            free(file->mats);
        }
        free(file);
    }
}

// ----------------------------------------------------------------------

static
AC3DObject *find_ac3d_object_object(AC3DObject *obj, const char *name)
{
    AC3DObject *o;
    int i;
    
    if (obj->name && !strcmp(obj->name, name)) 
        return obj;

    for (i=0; i<obj->numkids; i++) 
        if ((o = find_ac3d_object_object(obj->kids[i], name)))
            return o;

    return nil;
}

AC3DObject *find_ac3d_object(AC3DFile *file, const char *name)
{
    if (file->obj)
        return find_ac3d_object_object(file->obj, name);

    return NULL;
}

void set_rotation_ac3d_object(AC3DObject *obj, float angle)
{
    if (obj)
        obj->angle = angle;
}

int is_enabled_ac3d_object(AC3DObject *obj)
{
    if (obj)
        return obj->enabled ? 1 : 0;
    return -1;
}

void set_enabled_ac3d_object(AC3DObject *obj, int flag)
{
    if (obj)
        obj->enabled = flag ? true : false;
}

// ----------------------------------------------------------------------

void get_ac3d_material(AC3DFile *file, 
                       int index,   
                       float  *rgb,
                       float  *amb,
                       float  *emis,
                       float  *spec,
                       float  *shi,
                       float  *trans)
{
    if (!file) return;
    int j;
    if (index >=0 && 
        index < file->nummats) {
#define COPY( _field ) \
if (_field) for (j=0;j<3;j++) _field[j] = file->mats[index]->_field[j]
        COPY( rgb );
        COPY( amb );
        COPY( emis );
        COPY( spec );
        if (shi) *shi = file->mats[index]->shi;
        if (trans) *trans = 1.0 - file->mats[index]->rgb[3];
#undef COPY
    }
}

void set_ac3d_material(AC3DFile *file, 
                       int index,   
                       float  *rgb,
                       float  *amb,
                       float  *emis,
                       float  *spec,
                       float  shi,
                       float  trans)
{
    if (!file) return;
    int j;
    if (index >=0 && 
        index < file->nummats) {
#define COPY( _field ) \
if (_field) for (j=0;j<3;j++) file->mats[index]->_field[j] = _field[j]
        COPY( rgb );
        COPY( amb );
        COPY( emis );
        COPY( spec );
        if (shi >= 0.0)
            file->mats[index]->shi = shi;
        if (trans >= 0.0) {
            file->mats[index]->rgb[3] = 1.0-trans;
            file->mats[index]->amb[3] = 1.0-trans;
        }
        lastMat = -1;
#undef COPY
    }
}

// ----------------------------------------------------------------------

static
void set_ac3d_texture_object(AC3DObject *obj,
                             char *texture_name,
                             int texid)
{
    int i;
    if (obj->texture && !strcmp(obj->texture, texture_name)) {
        obj->texid = texid;
        if (texid == -1)
            obj->texture_loaded = 0;
    }
    for (i=0; i<obj->numkids; i++) 
        set_ac3d_texture_object(obj->kids[i], texture_name, texid);
}

void set_ac3d_texture(AC3DFile *file, 
                      char *texture_name,
                      int texid)
{
    if (!file->obj->texture_loaded) {
        init_ac3d_textures();
        load_textures_ac3d_object(file->obj, textures);
    }
    set_ac3d_texture_object(file->obj, texture_name, texid);
}

void set_ac3d_texture_named(AC3DFile *file, 
                            char *texture_name_org,
                            char *texture_name_new)
{
    int texid = -1;
    
    NSString *texname = [NSString stringWithFormat:@"%s", texture_name_new];
    AC3DTexture *texture = [textures objectForKey:texname];
    if (texture) {
        texid = [texture name];
    } else {
        texture = [[AC3DTexture alloc] initWithImagePath:texname];
        if (texture) {
            texid = [texture name];
            [textures setObject:texture forKey:texname];
        } else {
            texname = [NSString stringWithFormat:@"Textures/%s", texture_name_new];
            texture = [textures objectForKey:texname];
            if (texture) {
                texid = [texture name];
            } else {
                texture = [[AC3DTexture alloc] initWithImagePath:texname];
                if (texture) {
                    texid = [texture name];
                    [textures setObject:texture forKey:texname];
                }
            }
        }
    }
    if (texid > -1)
        set_ac3d_texture(file, texture_name_org, texid);
}

void reset_ac3d_texture(AC3DFile *file, 
                        char *texture_name)
{
    if (!file->obj->texture_loaded) {
        init_ac3d_textures();
        load_textures_ac3d_object(file->obj, textures);
    }
    AC3DTexture *tex = [textures objectForKey:[NSString stringWithFormat:@"%s", texture_name]];
    if (tex)
        set_ac3d_texture(file, texture_name, tex.name);
}

// ----------------------------------------------------------------------

static 
void normalize(float *v)
{
    float len = sqrt(v[0]*v[0] + v[1]*v[1] + v[2]*v[2]);
    
    if (len < 0.00000001) {
        v[0] = v[1] = 0.0;
        v[2] = 1.0;
        return;
    }
    
    v[0] /= len;
    v[1] /= len;
    v[2] /= len;
}

static 
void cross(float *dst, float *a, float *b)
{
    dst[0] = a[1]*b[2] - a[2]*b[1];
    dst[1] = a[2]*b[0] - a[0]*b[2];
    dst[2] = a[0]*b[1] - a[1]*b[0];
}

static 
void make_normal(float *dst, float *a, float *b, float *c)
{
    float ab[3];
    float ac[3];
    ab[0] = b[0]-a[0];
    ab[1] = b[1]-a[1];
    ab[2] = b[2]-a[2];
    normalize(ab);
    ac[0] = c[0]-a[0];
    ac[1] = c[1]-a[1];
    ac[2] = c[2]-a[2];
    normalize(ac);
    cross(dst, ab, ac);
    normalize(dst);
}

static
void fix_object_bbox(AC3DObject *obj) 
{
    if (obj->bbox && obj->loc) {
        // TODO: Apply rotmatrix
        obj->bbox[0] += obj->loc[0];
        obj->bbox[1] += obj->loc[1];
        obj->bbox[2] += obj->loc[2];
        obj->bbox[3] += obj->loc[0];
        obj->bbox[4] += obj->loc[1];
        obj->bbox[5] += obj->loc[2];
    }
}

static
void check_object_bbox(AC3DObject *obj, float *xyz) 
{
    if (obj->bbox) {
        // Min
        if (obj->bbox[0] > xyz[0]) obj->bbox[0] = xyz[0];
        if (obj->bbox[1] > xyz[1]) obj->bbox[1] = xyz[1];
        if (obj->bbox[2] > xyz[2]) obj->bbox[2] = xyz[2];
        // Max
        if (obj->bbox[3] < xyz[0]) obj->bbox[3] = xyz[0];
        if (obj->bbox[4] < xyz[1]) obj->bbox[4] = xyz[1];
        if (obj->bbox[5] < xyz[2]) obj->bbox[5] = xyz[2];
    } else {
        obj->bbox = (float*)malloc(sizeof(float)*6);
        // Min
        obj->bbox[0] = xyz[0];
        obj->bbox[1] = xyz[1];
        obj->bbox[2] = xyz[2];
        // Max
        obj->bbox[3] = xyz[0];
        obj->bbox[4] = xyz[1];
        obj->bbox[5] = xyz[2];      
    }
}

static
AC3DSurf *read_ac3d_surf(FILE *fp, AC3DObject *obj, char **err) 
{
    int do_read = 1;
    char buf[256];
    AC3DSurf *surf = (AC3DSurf*)malloc(sizeof(AC3DSurf));
    
    if (!surf)
        THROW( "malloc failed" );
    
    memset(surf, 0, sizeof(AC3DSurf));
    
    surf->mat = -1;
    
    while (do_read) {
        
        if (fscanf(fp, "%s", buf) != 1)
            THROW( "SURF failed" );
        
        if (!strcmp(buf, "SURF")) {
            if (fscanf(fp, "%x", &surf->type) != 1)
                THROW( "SURF type failed" );
        
        } else if (!strcmp(buf, "mat")) {
            if (fscanf(fp, "%d", &surf->mat) != 1) 
                THROW( "SURF mat failed" );
            
        } else if (!strcmp(buf, "refs")) {
            if (fscanf(fp, "%d", &surf->numrefs) != 1)
                THROW( "SURF refs failed" );
            
            if (surf->numrefs > 0) {
                int i;
                
                surf->vrefs = (short*)malloc(sizeof(short)*surf->numrefs);
                surf->texrefs = (AC3Dtexref*)malloc(sizeof(AC3Dtexref)*surf->numrefs);

                if (!surf->vrefs || !surf->texrefs)
                    THROW( "malloc failed" );
                
                for (i=0; i<surf->numrefs; i++) {
                    if (fscanf(fp, 
                               "%hd %f %f", 
                               &surf->vrefs[i],
                               &surf->texrefs[i].texu, 
                               &surf->texrefs[i].texv) != 3)
                        THROW( "SURF ref failed" );
                }
                
                if (surf->numrefs > 2) {
                    make_normal(surf->normal, 
                                obj->verts[surf->vrefs[0]], 
                                obj->verts[surf->vrefs[1]], 
                                obj->verts[surf->vrefs[2]]);
                }
            }
            do_read = 0; // done
            
        } else {
            THROW( "SURF unknown tag" );
        }
        
    }
    
    return surf;
    
CATCH_ERROR:

    free_ac3d_surf(surf);
    return NULL;
}

static 
void scan_string(FILE *fp, char *buf)
{
    int c;
    do {
        c = fgetc(fp);
    } while (c != EOF && c != '"');
    do {
        c = fgetc(fp);
        if (c != EOF && c != '"')
            *buf++ = c;
    } while (c != EOF && c != '"'); 
    *buf = '\0';
}

static
AC3DMaterial *read_ac3d_material(FILE *fp, char **err) 
{
    char buf[256];
    AC3DMaterial *mat = (AC3DMaterial*)malloc(sizeof(AC3DMaterial));
    float trans;
    
    if (!mat)
        THROW( "malloc failed" );
    
    memset(mat, 0, sizeof(AC3DMaterial));
    
    scan_string(fp, buf);
    
    if (fscanf(fp, 
               " rgb %f %f %f "
               "amb %f %f %f "
               "emis %f %f %f "
               "spec %f %f %f "
               "shi %f "
               "trans %f",
               &mat->rgb[0], &mat->rgb[1], &mat->rgb[2],
               &mat->amb[0], &mat->amb[1], &mat->amb[2],
               &mat->emis[0], &mat->emis[1], &mat->emis[2],
               &mat->spec[0], &mat->spec[1], &mat->spec[2],
               &mat->shi,
               &trans) != 14)
        THROW( "MATERIAL error" );
    
    mat->rgb[3]=1.0-trans;
    mat->amb[3]=1.0-trans;
    mat->emis[3]=1.0;
    mat->spec[3]=1.0;
    
    if (strlen(buf))
        mat->name = strdup(buf);
    
    return mat;
    
CATCH_ERROR:
    
    free_ac3d_material(mat);
    return NULL;
}

static
int find_surf_with_vertexes(int from, 
                            int to, 
                            AC3DSurf **surfs,
                            int mat,
                            short a, short b,
                            AC3Dtexref texa, AC3Dtexref texb)
{
    for (;from < to; from++) {
        AC3DSurf *surf = surfs[from];
        if (surf->numrefs == 3 &&
            (surf->type & 0x0f) == SURF_POLYGON &&
            surf->mat == mat) {
            if (surf->vrefs[0] == a &&
                surf->vrefs[1] == b && 
                fabs((surf->texrefs[0].texu-texa.texu) + 
                     (surf->texrefs[0].texv-texa.texv)) < 0.0001 &&
                fabs((surf->texrefs[1].texu-texb.texu) + 
                     (surf->texrefs[1].texv-texb.texv)) < 0.0001) {
                return (from << 2) + 2;
            } else if (surf->vrefs[1] == a &&
                       surf->vrefs[2] == b && 
                       fabs((surf->texrefs[1].texu-texa.texu) + 
                            (surf->texrefs[1].texv-texa.texv)) < 0.0001 &&
                       fabs((surf->texrefs[2].texu-texb.texu) + 
                            (surf->texrefs[2].texv-texb.texv)) < 0.0001) {
                return (from << 2) + 0;
            } else if (surf->vrefs[2] == a &&
                       surf->vrefs[0] == b && 
                       fabs((surf->texrefs[2].texu-texa.texu) + 
                            (surf->texrefs[2].texv-texa.texv)) < 0.0001 &&
                       fabs((surf->texrefs[0].texu-texb.texu) + 
                            (surf->texrefs[0].texv-texb.texv)) < 0.0001) {
                return (from << 2) + 1;
            }
        }
    }
    return 0;
}

static
int find_surf_with_vertexes_notex(int from, 
                                  int to, 
                                  AC3DSurf **surfs,
                                  int mat,
                                  short a, short b)
{
    for (;from < to; from++) {
        AC3DSurf *surf = surfs[from];
        if (surf->numrefs == 3 &&
            (surf->type & 0x0f) == SURF_POLYGON &&
            surf->mat == mat) {
            if (surf->vrefs[0] == a &&
                surf->vrefs[1] == b) {
                return (from << 2) + 2;
            } else if (surf->vrefs[1] == a &&
                       surf->vrefs[2] == b) {
                return (from << 2) + 0;
            } else if (surf->vrefs[2] == a &&
                       surf->vrefs[0] == b) {
                return (from << 2) + 1;
            }
        }
    }
    return 0;
}

// This is a naive method to find some triangle strips. Feel free to make a better (but keep in
// mind that it shouldn't take too long time to run)
static
void optimize_ac3d_object_step_1(AC3DObject *obj)
{
    int i;
    for (i=0; i<obj->numsurf-1; i++) {
        AC3DSurf *surf = obj->surfs[i];
        int a=2, b=1;
        if (surf->numrefs == 3 && 
            (surf->type & 0x0f) == SURF_POLYGON) {
            int rc;
            if (obj->texture)
                rc = find_surf_with_vertexes(0, // from 
                                             obj->numsurf, // to 
                                             obj->surfs, 
                                             surf->mat,
                                             surf->vrefs[a], surf->vrefs[b],
                                             surf->texrefs[a], surf->texrefs[b]);
            else
                rc = find_surf_with_vertexes_notex(0, // from 
                                             obj->numsurf, // to 
                                             obj->surfs, 
                                             surf->mat,
                                             surf->vrefs[a], surf->vrefs[b]);
            if (rc) {
                ADD_STRIPS(1);
            } else {
                ADD_TRIS((surf->numrefs>2) ? surf->numrefs-2 : 0);
            }
            while (rc) {
                int idx1 = rc >> 2;
                int idx2 = rc & 0x03;
                surf->type = (surf->type & 0xf0) | SURF_TRI_STRIP;
                surf->numrefs++;
                surf->vrefs = (short*)realloc(surf->vrefs, sizeof(short)*surf->numrefs);
                surf->texrefs = (AC3Dtexref*)realloc(surf->texrefs, sizeof(AC3Dtexref)*surf->numrefs);
                surf->vrefs[surf->numrefs-1] = obj->surfs[idx1]->vrefs[idx2];
                surf->texrefs[surf->numrefs-1] = obj->surfs[idx1]->texrefs[idx2];
                {
                    AC3DSurf *tmp = obj->surfs[idx1];
                    obj->numsurf--;
                    obj->surfs[idx1] = obj->surfs[obj->numsurf];
                    free_ac3d_surf(tmp);
                    ADD_STRIPS_PTS(2);
                }
                if (a < b)
                    a += 2;
                else
                    b += 2;
                if (obj->texture)
                    rc = find_surf_with_vertexes(0, // from 
                                                 obj->numsurf, // to 
                                                 obj->surfs, 
                                                 surf->mat,
                                                 surf->vrefs[a], surf->vrefs[b],
                                                 surf->texrefs[a], surf->texrefs[b]);
                else
                    rc = find_surf_with_vertexes_notex(0, // from 
                                                       obj->numsurf, // to 
                                                       obj->surfs, 
                                                       surf->mat,
                                                       surf->vrefs[a], surf->vrefs[b]);
            }
            if ((surf->type & 0x0f) == SURF_TRI_STRIP) {
                ADD_TRIS(surf->numrefs-2);
            }
        }
    }
}

static
void optimize_ac3d_object_step_2(AC3DObject *obj)
{
    int i;
    AC3Doptcmd *ptr;
    obj->numcmds = 0;
    for (i=0; i<obj->numsurf; i++) {
        AC3DSurf *surf = obj->surfs[i];
        if ((surf->type & 0x0f) == SURF_POLYGON ||
            (surf->type & 0x0f) == SURF_TRI_STRIP) {

            if (surf->numrefs > 2) {
                obj->numcmds += 2;                   // type+len+mat
                obj->numcmds += surf->numrefs*3;     // vertex

                if (obj->texture)
                    obj->numcmds += surf->numrefs*2; // texcoord
                
                // single normal when...NONE SHADED and POLYGON
                if (!(surf->type & SURF_SHADED) &&
                    (surf->type & 0x0f) == SURF_POLYGON) {
                    obj->numcmds += 3;               // normal
                } else {
                    obj->numcmds += surf->numrefs*3; // normals
                }
            }
            
        } else {
            obj->numcmds += 2;                   // type+len+mat
            obj->numcmds += surf->numrefs*3;     // vertex
        }
    }
    ptr = obj->optcmds = (AC3Doptcmd*)malloc(sizeof(AC3Doptcmd)*obj->numcmds);
    if (!obj) return;
    memset(obj->optcmds, 0, sizeof(AC3Doptcmd)*obj->numcmds);
    for (i=0; i<obj->numsurf; i++) {
        int j;
        AC3DSurf *surf = obj->surfs[i];
        if (((surf->type & 0x0f) == SURF_POLYGON ||
             (surf->type & 0x0f) == SURF_TRI_STRIP)) {
            if (surf->numrefs > 2) {
                ptr->cmd[0] = surf->type;
                ptr->cmd[1] = surf->numrefs;
                ptr++;
                ptr->cmd[0] = surf->mat;
                ptr++;
                
                if (!(surf->type & SURF_SHADED) &&
                    (surf->type & 0x0f) == SURF_POLYGON) {
#ifdef USE_FLOATS
                    (ptr++)->f = surf->normal[0];
                    (ptr++)->f = surf->normal[1];
                    (ptr++)->f = surf->normal[2];
#else
                    (ptr++)->i = surf->normal[0] * 65536.0;
                    (ptr++)->i = surf->normal[1] * 65536.0;
                    (ptr++)->i = surf->normal[2] * 65536.0;
#endif
                }

/*
 
 Best Practices on the PowerVR MBX
 ▪   For best performance, you should interleave the standard vertex attributes in the following order: Position, Normal, Color, TexCoord0, TexCoord1, PointSize, Weight, MatrixIndex.
 
 ==>> V,N,T
 
 */
                
                for (j=0; j<surf->numrefs; j++) {
                    int idx = surf->vrefs[j];
                    check_object_bbox(obj, obj->verts[idx]);

                    // VERTEX DATA
#ifdef USE_FLOATS
                    (ptr++)->f = obj->verts[idx][0];
                    (ptr++)->f = obj->verts[idx][1];
                    (ptr++)->f = obj->verts[idx][2];
#else
                    (ptr++)->i = obj->verts[idx][0] * 65536.0;
                    (ptr++)->i = obj->verts[idx][1] * 65536.0;
                    (ptr++)->i = obj->verts[idx][2] * 65536.0;
#endif

                    // NORMAL DATA
                    if (surf->type & SURF_SHADED) {
#ifdef USE_FLOATS
                        (ptr++)->f = obj->verts[idx][3];
                        (ptr++)->f = obj->verts[idx][4];
                        (ptr++)->f = obj->verts[idx][5];
#else
                        (ptr++)->i = obj->verts[idx][3] * 65536.0;
                        (ptr++)->i = obj->verts[idx][4] * 65536.0;
                        (ptr++)->i = obj->verts[idx][5] * 65536.0;
#endif
                    } else if ((surf->type & 0x0f) == SURF_TRI_STRIP) {
                        float n[3];
                        int i = j-2;
                        if (i < 0)
                            i = 0;
                        if (i%2)
                            make_normal(n, 
                                        obj->verts[surf->vrefs[i+1]], 
                                        obj->verts[surf->vrefs[i]], 
                                        obj->verts[surf->vrefs[i+2]]);
                        else
                            make_normal(n, 
                                        obj->verts[surf->vrefs[i]], 
                                        obj->verts[surf->vrefs[i+1]], 
                                        obj->verts[surf->vrefs[i+2]]);
#ifdef USE_FLOATS
                        (ptr++)->f = n[0];
                        (ptr++)->f = n[1];
                        (ptr++)->f = n[2];
#else
                        (ptr++)->i = n[0] * 65536.0;
                        (ptr++)->i = n[1] * 65536.0;
                        (ptr++)->i = n[2] * 65536.0;
#endif
                    } 
                    
                    // TEXTURE DATA
                    if (obj->texture) {
                        float repu = 1.0;
                        float repv = 1.0;
                        float offu = 0.0;
                        float offv = 0.0;
                        if (obj->texrep) {
                            repu = obj->texrep[0];
                            repv = obj->texrep[1];
                        }
                        if (obj->texoff) {
                            offu = obj->texoff[0];
                            offv = obj->texoff[1];
                        }
#ifdef USE_FLOATS
                        (ptr++)->f = (offu + surf->texrefs[j].texu*repu);
                        (ptr++)->f = (1.0 - (offv + surf->texrefs[j].texv*repv));
#else
                        (ptr++)->i = (offu + surf->texrefs[j].texu*repu)  * 65536.0;
                        (ptr++)->i = (1.0 - (offv + surf->texrefs[j].texv*repv))  * 65536.0;
#endif
                    }
                    
                }
            }
        } else {
            ptr->cmd[0] = surf->type;
            ptr->cmd[1] = surf->numrefs;
            ptr++;
            ptr->cmd[0] = surf->mat;
            ptr++;
            for (j=0; j<surf->numrefs; j++) {
                int idx = surf->vrefs[j];
                check_object_bbox(obj, obj->verts[idx]);
#ifdef USE_FLOATS
                (ptr++)->f = obj->verts[idx][0];
                (ptr++)->f = obj->verts[idx][1];
                (ptr++)->f = obj->verts[idx][2];
#else
                (ptr++)->i = obj->verts[idx][0] * 65536.0;
                (ptr++)->i = obj->verts[idx][1] * 65536.0;
                (ptr++)->i = obj->verts[idx][2] * 65536.0;
#endif
            }
        }       
    }
    if (obj->numvert > 0 && obj->verts) {
        free(obj->verts);
            obj->verts = NULL;
    }
    if (obj->numsurf > 0 && obj->surfs) {
        for (i=0; i<obj->numsurf; i++) {
            if (obj->surfs[i])
                free_ac3d_surf(obj->surfs[i]);
        }
        free(obj->surfs);
        obj->surfs = NULL;
    }
}

static
void make_normals(AC3DObject *obj)
{
    int i, j, k;
    for (i=0; i<obj->numvert; i++) {
        float n[3] = {0.0, 0.0, 0.0};
        int ns = 0;
        for (j=0; j<obj->numsurf; j++) {
            AC3DSurf *surf = obj->surfs[j];
            for (k=0; k<surf->numrefs; k++) {
                if (surf->vrefs[k] == i) {
                    n[0] += surf->normal[0];
                    n[1] += surf->normal[1];
                    n[2] += surf->normal[2];
                    ns++;
                }
            }
        }
        if (ns > 0) {
            n[0] /= ns;
            n[1] /= ns;
            n[2] /= ns;
        }
        obj->verts[i][3] = n[0];
        obj->verts[i][4] = n[1];
        obj->verts[i][5] = n[2];
    }
}

static
AC3DObject *read_ac3d_object(FILE *fp, char **err) 
{
    char buf[256];
    AC3DObject *obj = (AC3DObject*)malloc(sizeof(AC3DObject));
    int do_read = 1;
    
    memset(obj, 0, sizeof(AC3DObject));
    obj->texid = -1;
    obj->enabled = true;
    
    if (fscanf(fp, "%s", buf) != 1)
        THROW( "OBJECT header failed" );
    
    if      (!strcmp(buf, "world")) obj->type = OBJECT_WORLD;
    else if (!strcmp(buf, "poly"))  obj->type = OBJECT_POLY;
    else if (!strcmp(buf, "group")) obj->type = OBJECT_GROUP;
    else if (!strcmp(buf, "light")) obj->type = OBJECT_LIGHT;
    else 
        THROW( "OBJECT header type failed" );
    
    while (do_read) {
        
        if (fscanf(fp, "%s", buf) != 1)
            THROW( "OBJECT tag failed" );
        
        // ---------------------------------------
        // NAME
        
        if (!strcmp(buf, "name")) {
            scan_string(fp, buf);
            
            if (strlen(buf))
                obj->name = strdup(buf);
            
            // ---------------------------------------
            // DATA
            
        } else if (!strcmp(buf, "crease")) {
            float crease;
            if (fscanf(fp, "%f", &crease) != 1)
                THROW( "OBJECT crease failed" );
                        
            // ---------------------------------------
            // TEXTURE
            
        } else if (!strcmp(buf, "data")) {
            int i, len;
            char *ptr;
            
            if (fscanf(fp, "%d", &len) != 1)
                THROW( "OBJECT data len failed" );
            
            if (len > 0) {
                int c;
                ptr = (char*)malloc(len+1);
                if (!ptr)
                    THROW( "malloc failed" );
                do {
                    c = fgetc(fp);
                    if (c == EOF)
                        THROW( "data failed" );
                } while (c != '\n');
                for (i=0; i<len; i++) {
                    c = fgetc(fp);
                    if (c == EOF)
                        THROW( "data failed" );                 
                    ptr[i] = c;
                }
                ptr[i] = '\0';
#if TARGET_IPHONE_SIMULATOR
                NSLog(@"data: %s", ptr);
#endif
                free(ptr);
            }

            // ---------------------------------------
            // TEXTURE
            
        } else if (!strcmp(buf, "texture")) {
            char *ptr1, *ptr2;
            
            scan_string(fp, buf);
            ptr1 = buf;
            
            while ((ptr2 = strchr(ptr1, '/'))) {
                ptr1 = ++ptr2;
            }
            
            if (strlen(ptr1))
                obj->texture = strdup(ptr1);
            
            // ---------------------------------------
            // TEXREP
            
        } else if (!strcmp(buf, "texrep")) {
            float texrep[2];
            
            if (fscanf(fp, "%f %f", &texrep[0], &texrep[1]) != 2)
                THROW( "OBJECT texrep failed" );
            
            obj->texrep = (float*)malloc(sizeof(float)*2);
            
            if (!obj->texrep)
                THROW( "malloc failed" );
            
            memcpy(obj->texrep, &texrep, sizeof(float)*2);
            
            // ---------------------------------------
            // TEXOFF
            
        } else if (!strcmp(buf, "texoff")) {
            float texoff[2];
            
            if (fscanf(fp, "%f %f", &texoff[0], &texoff[1]) != 2)
                THROW( "OBJECT texoff failed" );
            
            obj->texoff = (float*)malloc(sizeof(float)*2);
            
            if (!obj->texoff)
                THROW( "malloc failed" );
            
            memcpy(obj->texoff, &texoff, sizeof(float)*2);
            
            // ---------------------------------------
            // ROT
            
        } else if (!strcmp(buf, "rot")) {
            float rot[16];
            
            rot[3] = 0.0;
            rot[7] = 0.0;
            rot[11] = 0.0;
            rot[12] = 0.0;
            rot[13] = 0.0;
            rot[14] = 0.0;
            rot[15] = 1.0;
            
            if (fscanf(fp, 
                       "%f %f %f "
                       "%f %f %f "
                       "%f %f %f", 
                       &rot[0], &rot[1], &rot[2],
                       &rot[4], &rot[5], &rot[6],
                       &rot[8], &rot[9], &rot[10]) != 9)
                THROW( "OBJECT rot failed" );
            
            obj->rot = (float*)malloc(sizeof(float)*16);
            
            if (!obj->rot)
                THROW( "malloc failed" );
            
            memcpy(obj->rot, &rot, sizeof(float)*16);
            
            // ---------------------------------------
            // LOC
            
        } else if (!strcmp(buf, "loc")) {
            float loc[3];
            
            if (fscanf(fp, "%f %f %f", &loc[0], &loc[1], &loc[2]) != 3)
                THROW( "OBJECT loc failed" );
            
            obj->loc = (float*)malloc(sizeof(float)*3);
            
            if (!obj->loc)
                THROW( "malloc failed" );
            
            memcpy(obj->loc, &loc, sizeof(float)*3);
            
            // ---------------------------------------
            // URL
            
        } else if (!strcmp(buf, "url")) {
            scan_string(fp, buf);
            
#if TARGET_IPHONE_SIMULATOR
            NSLog(@"url: %s", buf);
#endif          
            // ---------------------------------------
            // NUMVERT
            
        } else if (!strcmp(buf, "numvert")) {
            int i;
            
            if (fscanf(fp, "%d", &obj->numvert) != 1)
                THROW( "OBJECT numvert failed" );
            
            if (obj->numvert > 0) {
                obj->verts = (AC3DVert*)malloc(sizeof(AC3DVert)*obj->numvert);
                
                if (!obj->verts)
                    THROW( "malloc failed" );
                
                for (i=0; i<obj->numvert; i++) {
                    if (fscanf(fp, 
                               "%f %f %f", 
                               &obj->verts[i][0], 
                               &obj->verts[i][1], 
                               &obj->verts[i][2]) != 3)
                        THROW( "OBJECT vert failed" );
                    obj->verts[i][3] = obj->verts[i][4] = 0.0;
                }
            }
            
            // ---------------------------------------
            // NUMSURF
            
        } else if (!strcmp(buf, "numsurf")) {
            int i;
            
            if (fscanf(fp, "%d", &obj->numsurf) != 1)
                THROW( "OBJECT numsurf failed" );      
            
            if (obj->numsurf > 0) {
                obj->surfs = (AC3DSurf**)malloc(sizeof(AC3DSurf*)*obj->numsurf);
                
                if (!obj->surfs)
                    THROW( "malloc failed" );
                
                memset(obj->surfs, 0, sizeof(AC3DSurf*)*obj->numsurf);
                
                for (i=0; i<obj->numsurf; i++) {
                    AC3DSurf *surf = read_ac3d_surf(fp, obj, err);
                    
                    if (!surf)
                        THROW( *err );
                    
                    obj->surfs[i] = surf;
                }
                
                if (!obj->name || strcmp(obj->name, "rotate")) {
                    make_normals(obj);
                    optimize_ac3d_object_step_1(obj);
                    optimize_ac3d_object_step_2(obj);
                }
            }
            
            // ---------------------------------------
            // KIDS
            
        } else if (!strcmp(buf, "kids")) {
            
            if (fscanf(fp, "%d", &obj->numkids) != 1)
                THROW( "OBJECT kids failed" );
            
            if (obj->numkids > 0) {
                int i;
                
                obj->kids = (AC3DObject**)malloc(sizeof(AC3DObject*)*obj->numkids);
                
                if (!obj->kids)
                    THROW( "malloc failed" );
                
                memset(obj->kids, 0, sizeof(AC3DObject*)*obj->numkids);
                
                for (i=0; i<obj->numkids; i++) {
                    AC3DObject *kid;
                    
                    if (fscanf(fp, "%s", buf) != 1 || strcmp(buf, "OBJECT"))
                        THROW( "OBJECT kid object failed" );
                    
                    kid = read_ac3d_object(fp, err);
                    
                    if (kid)
                        ;//printf("Read object %s\n", kid->name ? kid->name : "unamed");
                    else
                        THROW( *err );
                    
                    if (kid->name && !strcmp(kid->name, "rotate")) {
                        if (!obj->rotvec) {
                            obj->rotvec = (float*)malloc(sizeof(float)*6);
                            obj->rotvec[0] = kid->verts[1][0] - kid->verts[0][0];
                            obj->rotvec[1] = kid->verts[1][1] - kid->verts[0][1];
                            obj->rotvec[2] = kid->verts[1][2] - kid->verts[0][2];
                            if (kid->loc) {
                                obj->rotvec[3] = kid->loc[0] + kid->verts[0][0];
                                obj->rotvec[4] = kid->loc[1] + kid->verts[0][1];
                                obj->rotvec[5] = kid->loc[2] + kid->verts[0][2];
                            } else {
                                obj->rotvec[3] = kid->verts[0][0];
                                obj->rotvec[4] = kid->verts[0][1];
                                obj->rotvec[5] = kid->verts[0][2];
                            }
                        }
                        free_ac3d_object(kid);
                        i--;
                        obj->numkids--;
                    } else if (kid->type == OBJECT_LIGHT) {
                        free_ac3d_object(kid);
                        i--;
                        obj->numkids--;
                    } else {
                        obj->kids[i] = kid;
                        if (kid->bbox) {
                            check_object_bbox(obj, &kid->bbox[0]);
                            check_object_bbox(obj, &kid->bbox[3]);
                        }
                    }
                }
            }
            fix_object_bbox(obj);
            do_read = 0; // done
            
        } else {
            THROW( "OBJECT unknown tag" );
        }
        
    }
    
    return obj;
    
CATCH_ERROR:
    
    free_ac3d_object(obj);
    return NULL;
}

// ----------------------------------------------------------------------

static
void load_textures_ac3d_object(AC3DObject *obj, 
                               NSMutableDictionary *textures)
{
    int i;
    if (obj->texture && !obj->texture_loaded) {
        NSString *texname = [NSString stringWithFormat:@"%s", obj->texture];
        AC3DTexture *texture = [textures objectForKey:texname];
        if (texture) {
            obj->texid = [texture name];
        } else {
            texture = [[AC3DTexture alloc] initWithImagePath:texname];
            if (texture) {
                obj->texid = [texture name];
                [textures setObject:texture forKey:texname];
            } else {
                texname = [NSString stringWithFormat:@"Textures/%s", obj->texture];
                texture = [textures objectForKey:texname];
                if (texture) {
                    obj->texid = [texture name];
                } else {
                    texture = [[AC3DTexture alloc] initWithImagePath:texname];
                    if (texture) {
                        obj->texid = [texture name];
                        [textures setObject:texture forKey:texname];
                    }
                }
            }
        }
        obj->texture_loaded = 1;
    }
    for (i=0; i<obj->numkids; i++) 
        load_textures_ac3d_object(obj->kids[i], textures);
}

AC3DFile *read_ac3d_file(const char *filename, char **err) 
{
#if TARGET_IPHONE_SIMULATOR
    NSLog(@"File %s", filename);
#endif
    
    const char *lfilename = [[[[NSBundle mainBundle] resourcePath] 
                              stringByAppendingPathComponent:[NSString stringWithFormat:@"%s", filename]] 
                             cStringUsingEncoding:NSUTF8StringEncoding];
    
    INIT_STATS;

    char buf[256];
    FILE *fp = fopen(lfilename, "rt");
    AC3DFile *file = NULL;
    int numobjs = 1;
    
    if (!fp) {
        lfilename = [[[[NSBundle mainBundle] resourcePath] 
                      stringByAppendingPathComponent:[NSString stringWithFormat:@"Models/%s", filename]] 
                     cStringUsingEncoding:NSUTF8StringEncoding];
        fp = fopen(lfilename, "rt");
        if (!fp)
            THROW( "fopen failed" );
    }
    
    file = (AC3DFile*)malloc(sizeof(AC3DFile));
    if (!file)
        THROW( "malloc failed" );
    
    memset(file, 0, sizeof(AC3DFile));
    
    if (fscanf(fp, "%s", buf) != 1 || strcmp(buf, "AC3Db"))
        THROW( "Wrong header" );
    
    while (numobjs) {
        if (fscanf(fp, "%s", buf) == -1 || (strcmp(buf, "MATERIAL") && 
                                            strcmp(buf, "OBJECT")))
            THROW( "Missing MATERIAL or OBJECT" );
        
        if (!strcmp(buf, "MATERIAL")) {
            AC3DMaterial *mat = read_ac3d_material(fp, err);
            
            if (mat)
                ; //printf("Read %s\n", mat->name);
            else
                THROW( *err );
            
            file->nummats++;
            file->mats = (AC3DMaterial**)realloc(file->mats,
                                                 sizeof(AC3DMaterial*) * 
                                                 file->nummats);
            if (!file->mats)
                THROW( "realloc failed" );
            
            file->mats[file->nummats-1] = mat;
            
        } else if (!strcmp(buf, "OBJECT")) {
            
            file->obj = read_ac3d_object(fp, err);

            if (file->obj) {
                file->bbox = file->obj->bbox; 
                //printf("Read object %s\n", file->obj->name ? file->obj->name : "unamed");
            } else {
                THROW( *err );
            }
            
            numobjs--;
        }
    } 

    fclose(fp);
        
    SHOW_STATS;
    
    return file;
    
CATCH_ERROR:
    
    fclose(fp);
    free_ac3d_file(file);
    return NULL;
}

// ----------------------------------------------------------------------
static
void set_ac3d_material_priv(int idx, AC3DFile *file)
{
    static AC3DFile *lastFile = NULL;
    
    if (idx < 0 || idx >= file->nummats)
        return;

    if (lastMat == idx &&
        lastFile == file)
        return;
    
    lastMat = idx;
    lastFile = file;
    
    glColor4f(file->mats[idx]->rgb[0],
              file->mats[idx]->rgb[1],
              file->mats[idx]->rgb[2],
              file->mats[idx]->rgb[3]);
    
    glMaterialfv( GL_FRONT_AND_BACK, GL_DIFFUSE,   file->mats[idx]->rgb  );
    glMaterialfv( GL_FRONT_AND_BACK, GL_AMBIENT,   file->mats[idx]->amb  );
    glMaterialfv( GL_FRONT_AND_BACK, GL_EMISSION,  file->mats[idx]->emis );
    glMaterialfv( GL_FRONT_AND_BACK, GL_SPECULAR,  file->mats[idx]->spec );
    glMaterialf(  GL_FRONT_AND_BACK, GL_SHININESS, file->mats[idx]->shi  );
}

void draw_ac3d_object(AC3DObject *obj, AC3DFile *file)
{
    int i, j;

    if (!obj->enabled) 
        return;
    
#ifdef USE_VBO
    if (!obj->vbo) {
        glGenBuffers(1, &obj->vbo);
        glBindBuffer(GL_ARRAY_BUFFER, obj->vbo);
        glBufferData(GL_ARRAY_BUFFER, sizeof(AC3Doptcmd)*obj->numcmds, obj->optcmds, GL_STATIC_DRAW); 
    } else {
        glBindBuffer(GL_ARRAY_BUFFER, obj->vbo);
    }
#endif
    
    if (!obj->texture_loaded) {
        init_ac3d_textures();
        load_textures_ac3d_object(file->obj, textures);
    }
    
    if (obj->texid == -1) {
        glDisable(GL_TEXTURE_2D);
    } else {
        glEnable(GL_TEXTURE_2D);
        glBindTexture(GL_TEXTURE_2D, obj->texid);
    }
    
    if (obj->loc || obj->rot || obj->rotvec) {
        glPushMatrix();
        
        if (obj->loc)
            glTranslatef(obj->loc[0], obj->loc[1], obj->loc[2]);

        if (obj->rot) 
            glMultMatrixf(obj->rot);
        
        if (obj->rotvec) {
            glTranslatef(obj->rotvec[3], obj->rotvec[4], obj->rotvec[5]);
            glRotatef(obj->angle, obj->rotvec[0], obj->rotvec[1], obj->rotvec[2]);
            glTranslatef(-obj->rotvec[3], -obj->rotvec[4], -obj->rotvec[5]);
        }
    }
    
    {
        i=0;
        AC3Doptcmd *ptr = obj->optcmds;
        AC3Doptcmd *ptrNext;
        while (i < obj->numcmds) {
            int type;
            int numrefs;
            int mat;
            int stride = 3;
            bool useNormalArray = false;
            
            type = ptr->cmd[0];
            numrefs = ptr->cmd[1];
            ptr++; i++;
            mat = ptr->cmd[0];
            ptr++; i++;
            
            set_ac3d_material_priv(mat, file);
#if 0
/*
 2009-08-10 00:46:44.722 AC3D test[2480:20b] 2
 2009-08-10 00:46:44.723 AC3D test[2480:20b] 16
 2009-08-10 00:46:44.735 AC3D test[2480:20b] 120
 2009-08-10 00:46:44.736 AC3D test[2480:20b] 134
 2009-08-10 00:46:44.739 AC3D test[2480:20b] 238
 2009-08-10 00:46:44.743 AC3D test[2480:20b] 318
 2009-08-10 00:46:44.745 AC3D test[2480:20b] 362
 2009-08-10 00:46:44.748 AC3D test[2480:20b] 442
 2009-08-10 00:46:44.749 AC3D test[2480:20b] 486
 2009-08-10 00:46:44.750 AC3D test[2480:20b] 530
 2009-08-10 00:46:44.751 AC3D test[2480:20b] 610
 2009-08-10 00:46:44.752 AC3D test[2480:20b] 642
 2009-08-10 00:46:44.753 AC3D test[2480:20b] 734
 2009-08-10 00:46:44.753 AC3D test[2480:20b] 826
 2009-08-10 00:46:44.754 AC3D test[2480:20b] 858
 2009-08-10 00:46:44.755 AC3D test[2480:20b] 962
            if (i==362) {
                srand(ptr);
                float rgb[4];
                rgb[0] = (rand()%32768)/32768.0;
                rgb[1] = (rand()%32768)/32768.0;
                rgb[2] = (rand()%32768)/32768.0;            
                rgb[3] = 1.0;
                glMaterialfv( GL_FRONT_AND_BACK, GL_DIFFUSE,   rgb  );
            }
 */
#endif
            if ((type & 0x0f) == SURF_POLYGON ||
                (type & 0x0f) == SURF_TRI_STRIP) {
                                
                if (obj->texture)
                    stride += 2;
                
                if (type & SURF_TWOSIDED) {
                    glLightModelf(GL_LIGHT_MODEL_TWO_SIDE, GL_TRUE);
                    glDisable(GL_CULL_FACE);
                } else {
                    glLightModelf(GL_LIGHT_MODEL_TWO_SIDE, GL_FALSE);
                    glEnable(GL_CULL_FACE);
                }
                
                if (type & SURF_SHADED) {
                    stride += 3;
                    glShadeModel(GL_SMOOTH);
                    useNormalArray = true;
                } else if ((type & 0x0f) == SURF_TRI_STRIP) {
                    stride += 3;
                    glShadeModel(GL_FLAT);
                    useNormalArray = true;
                } else {
                    glShadeModel(GL_FLAT);
#ifdef USE_FLOATS
                    glNormal3f(ptr[0].f, ptr[1].f, ptr[2].f);
#else
                    glNormal3x(ptr[0].i, ptr[1].i, ptr[2].i);
#endif
                    ptr+=3; i+=3;
                }
            }
            
            ptrNext = &ptr[stride*numrefs];
            j = i;
            i += stride*numrefs;
            stride *= sizeof(float);

            if ((type & 0x0f) == SURF_POLYGON ||
                (type & 0x0f) == SURF_TRI_STRIP) {
                //glEnable(GL_LIGHTING);
                
                glEnableClientState(GL_VERTEX_ARRAY);
#ifdef USE_FLOATS
                glVertexPointer(3, GL_FLOAT, stride, obj->vbo ? (void*)(j*4) : ptr);
#else
                glVertexPointer(3, GL_FIXED, stride, obj->vbo ? (void*)(j*4) : ptr);
#endif
                ptr+=3; j+=3;
                
                if (useNormalArray) {
                    glEnableClientState(GL_NORMAL_ARRAY);
#ifdef USE_FLOATS
                    glNormalPointer(GL_FLOAT, stride, obj->vbo ? (void*)(j*4) : ptr);
#else
                    glNormalPointer(GL_FIXED, stride, obj->vbo ? (void*)(j*4) : ptr);
#endif
                    ptr+=3; j+=3;
                }

                if (obj->texture) {
                    glEnableClientState(GL_TEXTURE_COORD_ARRAY);
#ifdef USE_FLOATS
                    glTexCoordPointer(2, GL_FLOAT, stride, obj->vbo ? (void*)(j*4) : ptr);
#else
                    glTexCoordPointer(2, GL_FIXED, stride, obj->vbo ? (void*)(j*4) : ptr);
#endif
                    ptr+=2; j+=2;
                }
                
                if ((type & 0x0f) == SURF_TRI_STRIP)
                    glDrawArrays(GL_TRIANGLE_STRIP, 0, numrefs);
                else
                    glDrawArrays(GL_TRIANGLE_FAN, 0, numrefs);
                
                glDisableClientState(GL_NORMAL_ARRAY);
                glDisableClientState(GL_TEXTURE_COORD_ARRAY);
                
            } else {

                glEnableClientState(GL_VERTEX_ARRAY);
#ifdef USE_FLOATS
                glVertexPointer(3, GL_FLOAT, stride, obj->vbo ? (void*)(j*4) : ptr);
#else
                glVertexPointer(3, GL_FIXED, stride, obj->vbo ? (void*)(j*4) : ptr);
#endif
                ptr+=3; j+=3;
                
                GLboolean hadLighting = glIsEnabled(GL_LIGHTING);
                if (hadLighting)
                    glDisable(GL_LIGHTING);
                switch (type & 0x0f) {
                    case SURF_CLOSEDLINE:
                        glDrawArrays(GL_LINE_LOOP, 0, numrefs);
                        break;
                        
                    case SURF_LINE:
                        glDrawArrays(GL_LINE_STRIP, 0, numrefs);
                        break;
                }
                if (hadLighting)
                    glEnable(GL_LIGHTING);
            }
            glDisableClientState(GL_VERTEX_ARRAY);
            ptr = ptrNext;
        }
    }
    
    for (i=0; i<obj->numkids; i++) 
        draw_ac3d_object(obj->kids[i], file);
    
    if (obj->loc || obj->rot || obj->rotvec) {
        glPopMatrix();
    }
}

void draw_ac3d_file(AC3DFile *file)
{
    draw_ac3d_object(file->obj, file);
}

float *get_ac3d_bbox(AC3DFile *file)
{
    return file->bbox;
}

void draw_ac3d_bbox(AC3DFile *file)
{
    if (file->bbox) {
        float vec[] = { 
            file->bbox[0+0], file->bbox[1+0], file->bbox[2+0], 
            file->bbox[0+3], file->bbox[1+0], file->bbox[2+0], 
            file->bbox[0+3], file->bbox[1+3], file->bbox[2+0], 
            file->bbox[0+0], file->bbox[1+3], file->bbox[2+0], 
            
            file->bbox[0+0], file->bbox[1+0], file->bbox[2+3], 
            file->bbox[0+3], file->bbox[1+0], file->bbox[2+3], 
            file->bbox[0+3], file->bbox[1+3], file->bbox[2+3], 
            file->bbox[0+0], file->bbox[1+3], file->bbox[2+3], 
            
            file->bbox[0+0], file->bbox[1+0], file->bbox[2+0], 
            file->bbox[0+0], file->bbox[1+0], file->bbox[2+3], 
            
            file->bbox[0+3], file->bbox[1+0], file->bbox[2+0], 
            file->bbox[0+3], file->bbox[1+0], file->bbox[2+3], 
            
            file->bbox[0+3], file->bbox[1+3], file->bbox[2+0], 
            file->bbox[0+3], file->bbox[1+3], file->bbox[2+3], 
            
            file->bbox[0+0], file->bbox[1+3], file->bbox[2+0], 
            file->bbox[0+0], file->bbox[1+3], file->bbox[2+3], 
        };
        GLboolean hadLighting = glIsEnabled(GL_LIGHTING);
        if (hadLighting)
          glDisable(GL_LIGHTING);
        glDisable(GL_TEXTURE_2D);
        glColor4f(1.0, 0.0, 0.0, 1.0);
        glEnableClientState(GL_VERTEX_ARRAY);
        glVertexPointer(3, GL_FLOAT, 0, vec);
        glDrawArrays(GL_LINE_LOOP,   0, 4);
        glDrawArrays(GL_LINE_LOOP,   4, 4);
        glDrawArrays(GL_LINE_STRIP,  8, 2);
        glDrawArrays(GL_LINE_STRIP, 10, 2);
        glDrawArrays(GL_LINE_STRIP, 12, 2);
        glDrawArrays(GL_LINE_STRIP, 14, 2);
        glDisableClientState(GL_VERTEX_ARRAY);
        glColor4f(1.0, 1.0, 1.0, 1.0);
        if (hadLighting)
          glEnable(GL_LIGHTING);
    }
}
