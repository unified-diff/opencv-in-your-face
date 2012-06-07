#import "OpticalFlowAppDelegate.h"


@interface OpticalFlowAppDelegate () {
    
    TrackMovement * trackMovement;
    
}
@end


@implementation OpticalFlowAppDelegate


- (void) applicationDidFinishLaunching:(NSNotification *)notification {
    [super applicationDidFinishLaunching:notification];
    
    trackMovement = [[TrackMovement alloc] init];
    [trackMovement setDelegate:self];
    
}

- (void) processImage:(CGImageRef)image {
    
    [trackMovement processImage:image];
    
    [super processImage:image];
    
}

- (void) willTrackMovement {
    [self.cameraView clearLines];
}

- (void) tracked:(CGPoint)source to:(CGPoint)destination {
    [self.cameraView line:source to:destination];
}


@end
