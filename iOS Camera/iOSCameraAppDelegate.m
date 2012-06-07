#import "iOSCameraAppDelegate.h"
#import "iOSCameraViewController.h"


@implementation iOSCameraAppDelegate

@synthesize window = _window;


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    
    //
    
    iOSCameraViewController * viewController = 
    [[iOSCameraViewController alloc] initWithNibName:@"iOSCameraViewController" 
                                              bundle:[NSBundle mainBundle]];
    [self.window setRootViewController:viewController];
    
    //
    
    [self.window makeKeyAndVisible];
    
    //
    
    [[UIApplication sharedApplication] setIdleTimerDisabled:YES];    
    
    return YES;
    
}


@end
