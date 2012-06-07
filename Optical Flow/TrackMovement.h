@protocol TrackMovementDelegate

- (void) willTrackMovement;
- (void) tracked:(CGPoint)source to:(CGPoint)destination;


@end


@interface TrackMovement : NSObject

- (void) setDelegate:(id <TrackMovementDelegate>)delegate_;
- (void) processImage:(CGImageRef)image;


@end
