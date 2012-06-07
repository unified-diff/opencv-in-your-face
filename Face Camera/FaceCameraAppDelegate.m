#import "FaceCameraAppDelegate.h"


@interface FaceCameraAppDelegate () {
    
    FindFaces * findFaces;
    BOOL willReceivePhoto;
    
}
@end


@implementation FaceCameraAppDelegate

@synthesize progressIndicator;


- (void) applicationDidFinishLaunching:(NSNotification *)notification {
    [super applicationDidFinishLaunching:notification];
    
    findFaces = [[FindFaces alloc] init];
    [findFaces setDelegate:self];
    
}

- (void) processImage:(CGImageRef)image {
    
    if ( willReceivePhoto ) {
        
        [self showPhoto:image];
        willReceivePhoto = NO;
        return;
        
    }
    
    [super processImage:image];
    
    static int framesBetweenSearch;
    framesBetweenSearch++;
    
    if ( framesBetweenSearch == 10 ) {
        [findFaces performSelectorInBackground:@selector(detect:) 
                                    withObject:(id)image];
        framesBetweenSearch = 0;
    }    
    
}

- (void) findFacesDidDetect {
    [self.cameraView clearHighlights];
}

- (void) findFacesFound:(CGRect)rect {
    [self.cameraView highlight:rect];
}

- (void) cameraView:(iOSCameraView *)cameraView didClickHighlight:(CGRect)rect {
    CGRect relativeRect = 
    CGRectMake( ( rect.origin.x * 2 ) / cameraView.bounds.size.height,
               ( rect.origin.y * 2 ) / cameraView.bounds.size.width,
               ( rect.size.width * 2 ) / cameraView.bounds.size.height, 
               ( rect.size.height * 2 ) / cameraView.bounds.size.width );
    
    char controlString[ 256 ] = "";
    snprintf( controlString, sizeof( controlString ) - 1,
             "photo %f %f %f %f", 
             relativeRect.origin.x, relativeRect.origin.y,
             relativeRect.size.width, relativeRect.size.height );
    
    [self sendToCamera:controlString];
    
    [self.progressIndicator startAnimation:nil];
    [self.cameraView setHidden:YES];
}

- (BOOL) willProcessData:(NSData *)data {
    if ( strncmp( (const char *)data.bytes, "photo", strlen( "photo" ) ) == 0 ) {
        willReceivePhoto = YES;
        return NO;
    }
    return YES;
}

- (void) showPhoto:(CGImageRef)image {
    
    CGRect imageRect = CGRectMake( 0, 0, CGImageGetWidth( image ), CGImageGetHeight( image ) );
    
    NSWindow * captureWindow =
    [[NSWindow alloc] initWithContentRect:NSRectFromCGRect( imageRect ) 
                                styleMask:( NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask | NSResizableWindowMask )
                                  backing:NSBackingStoreBuffered 
                                    defer:NO];
    [captureWindow setBackgroundColor:[NSColor blackColor]];
    
    NSImage * captureImage = [[NSImage alloc] initWithCGImage:image 
                                                         size:imageRect.size];
    
    NSImageView * captureImageView = [[NSImageView alloc] initWithFrame:imageRect];
    [captureImageView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [captureImageView setImageScaling:NSScaleProportionally];
    [captureImageView setImage:captureImage];
    [captureImage release];
    
    NSView * contentView = [captureWindow contentView];
    [contentView setAutoresizesSubviews:YES];
    [contentView addSubview:captureImageView];
    [captureImageView release];
    
    [captureWindow orderFront:nil];
    [captureWindow makeKeyWindow];
    
    //
    
    [self.progressIndicator stopAnimation:nil];
    [self.cameraView setHidden:NO];
    willReceivePhoto = NO;
    
}


@end
