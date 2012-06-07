@protocol FindFacesDelegate <NSObject>

- (void) findFacesDidDetect;
- (void) findFacesFound:(CGRect)rect;

@end


@interface FindFaces : NSObject

- (void) setDelegate:(id <FindFacesDelegate>)delegate;
- (void) detect:(CGImageRef)image;

@end

