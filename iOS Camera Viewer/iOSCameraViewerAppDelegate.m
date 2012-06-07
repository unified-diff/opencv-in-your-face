#import "iOSCameraViewerAppDelegate.h"


@interface iOSCameraViewerAppDelegate () {
    
    NSNetServiceBrowser * networkServiceBrowser;
	NSNetService * cameraService;
    GCDAsyncSocket * cameraSocket;
    NSData * separatorData;
    
}
@end


@implementation iOSCameraViewerAppDelegate

@synthesize window = _window, cameraView;


- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    
    [self.cameraView setDelegate:self];
    
    [self setupNetworking];
    
}

- (void) setupNetworking {
    
	networkServiceBrowser = [[NSNetServiceBrowser alloc] init];
	[networkServiceBrowser setDelegate:self];
    
    separatorData = 
    [[NSData dataWithData:[IOSCAMERA_SEPARATORSTRING dataUsingEncoding:NSUTF8StringEncoding]] retain];
    
    [self searchForCamera];
    
}

- (BOOL) applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

- (void) searchForCamera {
    if ( cameraSocket ) {
        return;
    }
    
    [networkServiceBrowser searchForServicesOfType:IOSCAMERA_SERVICETYPE
                                          inDomain:@""];
    
    [self performSelector:@selector(searchForCamera) 
               withObject:nil 
               afterDelay:1.0];
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)sender
           didFindService:(NSNetService *)service
               moreComing:(BOOL)moreServicesComing {	
    if ( cameraService ) {
        return;
    }
    cameraService = [service retain];
    [cameraService setDelegate:self];
    [cameraService resolveWithTimeout:-1];
}

- (void)netServiceDidResolveAddress:(NSNetService *)sender {
	if ( cameraSocket || ![[sender addresses] count]) {
        return;
    }    
    cameraSocket = [[GCDAsyncSocket alloc] initWithDelegate:self 
                                              delegateQueue:dispatch_get_main_queue()];
    [cameraSocket connectToAddress:[[sender addresses] objectAtIndex:0] 
                             error:nil];
}

- (void) socket:(GCDAsyncSocket *)socket didConnectToHost:(NSString *)host port:(uint16_t)port {
    [socket setDelegate:self];
    [socket readDataToData:separatorData withTimeout:-1 tag:0];
}

- (BOOL) willProcessData:(NSData *)data {
    return YES;
}

- (void)socket:(GCDAsyncSocket *)socket didReadData:(NSData *)data withTag:(long)tag {
    
    [socket readDataToData:separatorData withTimeout:-1 tag:0];
    
    if ( ![self willProcessData:data] ) {
        return;
    }
    
    CGDataProviderRef dataProvider =
    CGDataProviderCreateWithData( 0, data.bytes, data.length - [separatorData length], 0 );
    CGImageRef image = 
    CGImageCreateWithJPEGDataProvider( dataProvider, NULL, false, kCGRenderingIntentDefault );
    
    [self processImage:image];
    
    CGImageRelease( image );
    CGDataProviderRelease( dataProvider );
    [self performSelector:@selector( releaseData: ) 
               withObject:data 
               afterDelay:1.0];
    
}

- (void) processImage:(CGImageRef)image {
    [cameraView setImage:image];
}

- (void) releaseData:(NSData *)data {
    [data release];
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)socket withError:(NSError *)err {
    if ( socket == cameraSocket ) {
        [cameraSocket release];
        cameraSocket = nil;
        
        [cameraService release];
        cameraService = nil;
    }
}

- (void) sendToCamera:(const char *)controlString {
    NSData * controlData = [[NSData dataWithBytes:controlString 
                                           length:strlen( controlString )] retain];
    [cameraSocket writeData:controlData withTimeout:-1 tag:0];
    [cameraSocket writeData:separatorData withTimeout:-1 tag:0];
}

- (void) cameraView:(iOSCameraView *)cameraView didClickPoint:(CGPoint)point {
    char focusString[ 256 ] = "";
    snprintf( focusString, sizeof( focusString ) - 1, 
             "focus %f %f", 
             point.x / self.cameraView.bounds.size.width, 
             1.0 - ( point.y / self.cameraView.bounds.size.height ) ); 
    [self sendToCamera:focusString];
}



@end
