//
//  Thrust_DemoAppDelegate.h
//  Thrust Demo
//

#import <UIKit/UIKit.h>

@class EAGLView;

@interface Thrust_DemoAppDelegate : NSObject <UIApplicationDelegate> {
    UIWindow *window;
    EAGLView *glView;
}

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet EAGLView *glView;

@end

