@interface iOSCameraViewController : UIViewController
    <AVCaptureVideoDataOutputSampleBufferDelegate, 
     NSNetServiceDelegate>


@property (strong, nonatomic) IBOutlet UIView * previewContainerView;

- (IBAction) toggleDisplay:(id)sender;


@end
