//
//  EAGLView.m
//  TrafficLight Demo
//



#import <QuartzCore/QuartzCore.h>
#import <OpenGLES/EAGLDrawable.h>

#import "EAGLView.h"

#define USE_DEPTH_BUFFER 1

// A class extension to declare private methods
@interface EAGLView ()

@property (nonatomic, retain) EAGLContext *context;
@property (nonatomic, assign) NSTimer *animationTimer;

- (BOOL) createFramebuffer;
- (void) destroyFramebuffer;

@end


@implementation EAGLView

@synthesize context;
@synthesize animationTimer;
@synthesize animationInterval;


// You must implement this method
+ (Class)layerClass {
    return [CAEAGLLayer class];
}


//The GL view is stored in the nib file. When it's unarchived it's sent -initWithCoder:
- (id)initWithCoder:(NSCoder*)coder {
    
    if ((self = [super initWithCoder:coder])) {
        // Get the layer
        CAEAGLLayer *eaglLayer = (CAEAGLLayer *)self.layer;
        
        eaglLayer.opaque = YES;
        eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSNumber numberWithBool:NO], kEAGLDrawablePropertyRetainedBacking, kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat, nil];
        
        context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES1];
        
        if (!context || ![EAGLContext setCurrentContext:context]) {
            [self release];
            return nil;
        }
        
        char *err = NULL;
        sign = read_ac3d_file("tlight.ac", &err);
        if (err)
            NSLog(@"AC3D error: %s", err);
        
        animationInterval = 1.0 / 60.0;
    }
    return self;
}

- (void)setLight:(int)idx on:(BOOL)on
{
    float rgb[3];
    BOOL isOn = NO;
    
    get_ac3d_material(sign, 
                      idx, 
                      rgb, 
                      nil, 
                      nil, // emission, should be used for lighting when dark 
                      nil, 
                      nil, 
                      nil);
    
    // Check if the light is on
    if (rgb[0] > 0.9 ||
        rgb[1] > 0.9 ||
        rgb[2] > 0.9)
        isOn = YES;
    
    if (on && !isOn) {
        for (int i=0; i<3; i++) {
            rgb[i] *= 2.0; 
            if (rgb[i] > 1.0) 
                rgb[i] = 1.0;
        }
    }
    
    if (!on && isOn) {
        for (int i=0; i<3; i++) 
            rgb[i] /= 2.0; 
    }
    
    set_ac3d_material(sign, 
                      idx, 
                      rgb, 
                      nil, 
                      nil, // emission, should be used for lighting when dark 
                      nil, 
                      -1, 
                      -1);
}

- (void)drawView {
    [EAGLContext setCurrentContext:context];
    
    glBindFramebufferOES(GL_FRAMEBUFFER_OES, viewFramebuffer);
    glViewport(0, 0, backingWidth, backingHeight);
    
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glFrustumf(-.10f, .10f, -.15f, .15f, 0.1f, 100.0f);
    glMatrixMode(GL_MODELVIEW);
    
    glEnable(GL_DEPTH_TEST);
    
    glClearColor(0.2f, 0.2f, 0.2f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    glLoadIdentity();
    glTranslatef(0, -1, -0.8);
    glRotatef(20, 0, 1, 0);
    
    /*======================================================================
     
     Step the traffic lights here, indexes 2,3,4 was observed in the first part
     of the sign.ac file
     
     White  -> MATERIAL "ac3dmat1" rgb 1 1 1  amb 0.2 0.2 0.2  emis 0 0...
     Grey   -> MATERIAL "ac3dmat6" rgb 0.14902 0.14902 0.14902  amb 0.2...
     Red    -> MATERIAL "ac3dmat3" rgb 0.501961 0 0  amb 0.2 0.2 0.2  e...
     Orange -> MATERIAL "ac3dmat4" rgb 0.498039 0.247059 0  amb 0.2 0.2...
     Green  -> MATERIAL "ac3dmat6" rgb 0 0.498039 0  amb 0.2 0.2 0.2  e...
     
     *======================================================================*/
    static int frame = 0;
    frame++;
    switch (frame) {
        case 60:
            [self setLight:3 on:NO];
            [self setLight:4 on:YES];
            break;
        case 120:
            [self setLight:4 on:NO];
            [self setLight:3 on:YES];
            break;
        case 180:
            [self setLight:3 on:NO];
            [self setLight:2 on:YES];
            break;
        case 240:
            [self setLight:2 on:NO];
            [self setLight:3 on:YES];
            break;
        case 300:
            frame = 59;
            break;
    }
    
    draw_ac3d_file(sign);
    
    glBindRenderbufferOES(GL_RENDERBUFFER_OES, viewRenderbuffer);
    [context presentRenderbuffer:GL_RENDERBUFFER_OES];
}


- (void)layoutSubviews {
    [EAGLContext setCurrentContext:context];
    [self destroyFramebuffer];
    [self createFramebuffer];
    [self drawView];
}


- (BOOL)createFramebuffer {
    
    glGenFramebuffersOES(1, &viewFramebuffer);
    glGenRenderbuffersOES(1, &viewRenderbuffer);
    
    glBindFramebufferOES(GL_FRAMEBUFFER_OES, viewFramebuffer);
    glBindRenderbufferOES(GL_RENDERBUFFER_OES, viewRenderbuffer);
    [context renderbufferStorage:GL_RENDERBUFFER_OES fromDrawable:(CAEAGLLayer*)self.layer];
    glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_COLOR_ATTACHMENT0_OES, GL_RENDERBUFFER_OES, viewRenderbuffer);
    
    glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_WIDTH_OES, &backingWidth);
    glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_HEIGHT_OES, &backingHeight);
    
    if (USE_DEPTH_BUFFER) {
        glGenRenderbuffersOES(1, &depthRenderbuffer);
        glBindRenderbufferOES(GL_RENDERBUFFER_OES, depthRenderbuffer);
        glRenderbufferStorageOES(GL_RENDERBUFFER_OES, GL_DEPTH_COMPONENT16_OES, backingWidth, backingHeight);
        glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_DEPTH_ATTACHMENT_OES, GL_RENDERBUFFER_OES, depthRenderbuffer);
    }
    
    if(glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES) != GL_FRAMEBUFFER_COMPLETE_OES) {
        NSLog(@"failed to make complete framebuffer object %x", glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES));
        return NO;
    }
    
    return YES;
}

- (IBAction)setTexture:(id)sender
{
    UISwitch *sw = (UISwitch*)sender;
    if ([sw isOn]) {
        set_ac3d_texture_named(sign, "sign.png", "malmoe.png");
    } else {
        reset_ac3d_texture(sign, "sign.png");
    }
}

- (void)destroyFramebuffer {
    
    glDeleteFramebuffersOES(1, &viewFramebuffer);
    viewFramebuffer = 0;
    glDeleteRenderbuffersOES(1, &viewRenderbuffer);
    viewRenderbuffer = 0;
    
    if(depthRenderbuffer) {
        glDeleteRenderbuffersOES(1, &depthRenderbuffer);
        depthRenderbuffer = 0;
    }
}


- (void)startAnimation {
    self.animationTimer = [NSTimer scheduledTimerWithTimeInterval:animationInterval target:self selector:@selector(drawView) userInfo:nil repeats:YES];
}


- (void)stopAnimation {
    self.animationTimer = nil;
}


- (void)setAnimationTimer:(NSTimer *)newTimer {
    [animationTimer invalidate];
    animationTimer = newTimer;
}


- (void)setAnimationInterval:(NSTimeInterval)interval {
    
    animationInterval = interval;
    if (animationTimer) {
        [self stopAnimation];
        [self startAnimation];
    }
}


- (void)dealloc {
    
    [self stopAnimation];
    
    if ([EAGLContext currentContext] == context) {
        [EAGLContext setCurrentContext:nil];
    }
    
    [context release];  
    [super dealloc];
}

@end
