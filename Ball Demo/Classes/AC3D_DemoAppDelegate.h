//
//  AC3D_DemoAppDelegate.h
//  AC3D Demo
//

#import <UIKit/UIKit.h>

@class EAGLView;

@interface AC3D_DemoAppDelegate : NSObject <UIApplicationDelegate> {
    UIWindow *window;
    EAGLView *glView;
}

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet EAGLView *glView;

@end

