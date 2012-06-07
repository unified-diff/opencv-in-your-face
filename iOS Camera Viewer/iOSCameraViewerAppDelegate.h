#import "iOSCameraView.h"


@interface iOSCameraViewerAppDelegate : NSObject 
    <NSApplicationDelegate, NSNetServiceBrowserDelegate, NSNetServiceDelegate, 
     iOSCameraViewDelegate>


@property (assign) IBOutlet NSWindow * window;
@property (assign) IBOutlet iOSCameraView * cameraView;

- (void) processImage:(CGImageRef)image;
- (void) sendToCamera:(const char *)controlString;


@end
