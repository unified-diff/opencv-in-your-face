@protocol iOSCameraViewDelegate;


@interface iOSCameraView : NSOpenGLView

- (void) setDelegate:(id <iOSCameraViewDelegate>)delegate;
- (void) setImage:(CGImageRef)image;
- (void) clearHighlights;
- (void) highlight:(CGRect)rect;
- (void) clearLines;
- (void) line:(CGPoint)source to:(CGPoint)destination;
- (void) clearCircles;
- (void) circle:(CGRect)circle;


@end


@protocol iOSCameraViewDelegate <NSObject>

@optional
- (void) cameraView:(iOSCameraView *)cameraView didClickHighlight:(CGRect)rect;
- (void) cameraView:(iOSCameraView *)cameraView didClickPoint:(CGPoint)point;


@end

