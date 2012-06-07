#import "iOSCameraViewerAppDelegate.h"
#import "FindFaces.h"


@interface FaceCameraAppDelegate : iOSCameraViewerAppDelegate
    <FindFacesDelegate>

@property (nonatomic, retain) IBOutlet NSProgressIndicator * progressIndicator;


@end
