//
//  EAGLView.m
//  AC3D Demo
//

#define TABLE_WIDTH 3.5
#define TABLE_LENGTH 5.3
#define BALL_RADIUS 0.5

#import <QuartzCore/QuartzCore.h>
#import <OpenGLES/EAGLDrawable.h>

#import "EAGLView.h"

#include "Vector.h"

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
        
        Quaternion_loadIdentity(&quat);
        
        ballPosVel.x = 0;
        ballPosVel.y = 0;
        ballPosVel.z = 0;
        ballPosVel.dx = 0.04;
        ballPosVel.dy = 0.0;
        ballPosVel.dz = 0.045;
        
        char *err = NULL;
        ball = read_ac3d_file("ball.ac", &err);
        if (err)
            NSLog(@"AC3D error: %s", err);
        
        table = read_ac3d_file("table.ac", &err);
        if (err)
            NSLog(@"AC3D error: %s", err);
        
        shadow = read_ac3d_file("shadow.ac", &err);
        if (err)
            NSLog(@"AC3D error: %s", err);
        
        animationInterval = 1.0 / 60.0;
    }
    return self;
}


- (void)drawView {
    
    [EAGLContext setCurrentContext:context];
    
    glBindFramebufferOES(GL_FRAMEBUFFER_OES, viewFramebuffer);
    glViewport(0, 0, backingWidth, backingHeight);
    
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glFrustumf(-1.0f, 1.0f, -1.5f, 1.5f, 2.3f, 100.0f);
    glMatrixMode(GL_MODELVIEW);
    
    glClearColor(0.1f, 0.3f, 0.1f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    glLoadIdentity();
    glRotatef(40.0f, 1.0f, 0.0f, 0.0f);
    
    glTranslatef(0, -6, -8);
    
    glEnable(GL_LIGHTING);
    glEnable(GL_LIGHT0);
    glEnable(GL_DEPTH_TEST);
    
    draw_ac3d_file(table);
    
    ballPosVel.x += ballPosVel.dx;
    ballPosVel.y += ballPosVel.dy;
    ballPosVel.z += ballPosVel.dz;
    
    if (ballPosVel.x > TABLE_WIDTH-BALL_RADIUS) {
        ballPosVel.x = 2.0*(TABLE_WIDTH-BALL_RADIUS) - ballPosVel.x;
        ballPosVel.dx = -ballPosVel.dx;
    } 
    if (ballPosVel.x < -(TABLE_WIDTH-BALL_RADIUS)) {
        ballPosVel.x = -2.0*(TABLE_WIDTH-BALL_RADIUS) - ballPosVel.x;
        ballPosVel.dx = -ballPosVel.dx;
    }
    if (ballPosVel.z > TABLE_LENGTH-BALL_RADIUS) {
        ballPosVel.z = 2.0*(TABLE_LENGTH-BALL_RADIUS) - ballPosVel.z;
        ballPosVel.dz = -ballPosVel.dz;
    } 
    if (ballPosVel.z < -(TABLE_LENGTH-BALL_RADIUS)) {
        ballPosVel.z = -2.0*(TABLE_LENGTH-BALL_RADIUS) - ballPosVel.z;
        ballPosVel.dz = -ballPosVel.dz;
    }
    
    // Calculate rotation direction and angle
    Vector axis;
    float angle;
    
    axis.x = ballPosVel.dz;
    axis.y = 0.0;
    axis.z = -ballPosVel.dx;
    // Formula is angle = 2*pi*dist/(2*pi*r) which is reduced to below calculation
    angle = sqrt(ballPosVel.dx*ballPosVel.dx+ballPosVel.dz*ballPosVel.dz)/BALL_RADIUS;
    
    // Apply to rotation Quaternion (globally)
    Quaternion tmpQ;
    tmpQ = Quaternion_fromAxisAngle(axis, angle);
    quat = Quaternion_multiplied(tmpQ, quat);
    
    // Get the rotation in a usable format for OpenGL
    Quaternion_toAxisAngle(quat, &axis, &angle);
    
    // Position ball and shadow 
    glTranslatef(ballPosVel.x, ballPosVel.y, ballPosVel.z);
    
    // Draw a small shadow for effect
    draw_ac3d_file(shadow);
    
    // Make rotation and draw ball
    glRotatef(angle*180.0/M_PI, axis.x, axis.y, axis.z);    
    draw_ac3d_file(ball);
    
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
