/* ======================================================================
 * AC3D reader lib for iPhone
 * See license.txt (BSD license)
 * ====================================================================== */

#ifndef __AC3D_READER_H__
#define __AC3D_READER_H__

#ifdef __cplusplus
extern "C" {
#endif /* __cplusplus */
  
  typedef struct AC3DFile_s   AC3DFile;
  typedef struct AC3DObject_s AC3DObject;
  
  /* Load .ac file */
  AC3DFile   *read_ac3d_file(const char *filename, char **err);

  /* Lookup a node within the .ac model */
  AC3DObject *find_ac3d_object(AC3DFile *file, const char *name);
  void        set_rotation_ac3d_object(AC3DObject *obj, float angle);
  int         is_enabled_ac3d_object(AC3DObject *obj);
  void        set_enabled_ac3d_object(AC3DObject *obj, int flag);
    
  /* Control material settings */
  void        get_ac3d_material(AC3DFile *file, 
                                int index, /* from .ac file */
                                float  *rgb, /* 3 floats, nil not fetched */
                                float  *amb, /* 3 floats, nil not fetched */
                                float  *emis, /* 3 floats, nil not fetched */
                                float  *spec, /* 3 floats, nil not fetched */
                                float  *shi,
                                float  *trans);
  void        set_ac3d_material(AC3DFile *file, 
                                int index, /* from .ac file */
                                float  *rgb, /* 3 floats, nil not set */
                                float  *amb, /* 3 floats, nil not set */
                                float  *emis, /* 3 floats, nil not set */
                                float  *spec, /* 3 floats, nil not set */
                                float  shi, /* <0 = no change */
                                float  trans); /* <0 = no change */
    
  /* Control model textures */
  void        set_ac3d_texture(AC3DFile *file, 
                               char *texture_name,
                               int texid);
  void        set_ac3d_texture_named(AC3DFile *file, 
                                     char *texture_name_org,
                                     char *texture_name_new);
  void        reset_ac3d_texture(AC3DFile *file, 
                                 char *texture_name);
  
  /* Draw the model */
  void        draw_ac3d_file(AC3DFile *file);

  /* Get the bounding box, returns vector of 6 floats, min x,y,z max x,y,z */
  float      *get_ac3d_bbox(AC3DFile *file);

  /* Draw the bounding box */
  void        draw_ac3d_bbox(AC3DFile *file);

  /* Free memory used for all loaded textures */
  void        free_ac3d_textures();

  /* Free memory used for a model */
  void        free_ac3d_file(AC3DFile *file);
  
#ifdef __cplusplus
}
#endif /* __cplusplus */

#endif /* __AC3D_READER_H__ */
