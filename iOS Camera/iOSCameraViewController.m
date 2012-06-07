#import "iOSCameraViewController.h"


@interface iOSCameraViewController () {
    
    BOOL setup;
    
    // camera
    AVCaptureDevice * camera;
    AVCaptureVideoPreviewLayer * previewLayer;
    AVCaptureVideoDataOutput * previewOutput;
    AVCaptureSession * captureSession;
    AVCaptureStillImageOutput * photoOutput;
    dispatch_queue_t frameQueue;
    NSTimer * lockAdjustmentTimer;
    
    // network service
    NSNetService * networkService;
    GCDAsyncSocket * listenSocket;
    GCDAsyncSocket * viewerSocket;
    NSData * separatorData;
    BOOL transmitFrame;
    
}
@end


@implementation iOSCameraViewController

@synthesize previewContainerView;


- (void) viewDidAppear:(BOOL)animated {
    
    if ( !setup ) {
        
        [self setupCamera];
        [self setupNetworkService];
        
        [self switchToPreviewMode];
        
        setup = YES;
    }
    
}

- (void) setupNetworkService {
    
	listenSocket = 
    [[GCDAsyncSocket alloc] initWithDelegate:self 
                               delegateQueue:dispatch_get_main_queue()];
    [listenSocket acceptOnPort:0 error:nil];
    
    networkService = 
    [[NSNetService alloc] initWithDomain:@""
                                    type:IOSCAMERA_SERVICETYPE
                                    name:@""
                                    port:[listenSocket localPort]];
    [networkService setDelegate:self];
    [networkService publish];
    
    separatorData = 
    [NSData dataWithData:[IOSCAMERA_SEPARATORSTRING dataUsingEncoding:NSUTF8StringEncoding]];
    
}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return ( interfaceOrientation == UIInterfaceOrientationLandscapeRight );
}

- (void) setupCamera {
    
    camera = 
    [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    [camera lockForConfiguration:nil];
    [camera setFocusMode:AVCaptureFocusModeContinuousAutoFocus];
    [camera setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
    [camera setWhiteBalanceMode:AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance];
    [camera setTorchMode:AVCaptureTorchModeOff];
    [camera setFlashMode:AVCaptureFlashModeOff];
    [camera unlockForConfiguration];
    
    AVCaptureDeviceInput * cameraInput =
    [AVCaptureDeviceInput deviceInputWithDevice:camera error:nil];
    
    captureSession = [[AVCaptureSession alloc] init];
    [captureSession addInput:cameraInput];
    
    previewOutput = [[AVCaptureVideoDataOutput alloc] init];
    [previewOutput setVideoSettings:[NSDictionary dictionaryWithObjectsAndKeys:
                                     [NSNumber numberWithInt:kCVPixelFormatType_32BGRA], 
                                     kCVPixelBufferPixelFormatTypeKey,
                                     nil]];    
    
    photoOutput = [[AVCaptureStillImageOutput alloc] init];
    [photoOutput setOutputSettings:[NSDictionary dictionaryWithObjectsAndKeys:
                                    AVVideoCodecJPEG, AVVideoCodecKey,
                                    nil]];    
    
    previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:captureSession];
    [previewLayer setFrame:previewContainerView.bounds];
    [previewLayer setOrientation:AVCaptureVideoOrientationLandscapeRight];
    [previewLayer setVideoGravity:AVLayerVideoGravityResizeAspect];
    [[previewContainerView layer] addSublayer:previewLayer];
    
    frameQueue = dispatch_queue_create( "FrameQueue", NULL );
    [previewOutput setSampleBufferDelegate:self queue:frameQueue];
    dispatch_release( frameQueue );

}

- (IBAction) toggleDisplay:(id)sender {
    if ( [previewContainerView isHidden] ) {
        [previewContainerView setHidden:NO];
    }
    else if ( [[UIApplication sharedApplication] isStatusBarHidden] ) {
        [[UIApplication sharedApplication] setStatusBarHidden:NO];
    }
    else {
        [previewContainerView setHidden:YES];
        [[UIApplication sharedApplication] setStatusBarHidden:YES];        
    }
}

- (void) switchToPreviewMode {
    [captureSession stopRunning];
    [captureSession setSessionPreset:AVCaptureSessionPresetHigh];
    [captureSession removeOutput:photoOutput];
    [captureSession removeOutput:previewOutput];
    [captureSession addOutput:previewOutput];
    [captureSession startRunning];
}

- (void) switchToPhotoMode {
    [captureSession stopRunning];
    [captureSession setSessionPreset:AVCaptureSessionPresetPhoto];
    [captureSession removeOutput:previewOutput];
    [captureSession removeOutput:photoOutput];
    [captureSession addOutput:photoOutput];
    [captureSession startRunning];
}

- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket {
    viewerSocket = newSocket;
    
    [viewerSocket readDataToData:separatorData withTimeout:-1 tag:0];
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
    viewerSocket = nil;
}

- (void)socket:(GCDAsyncSocket *)socket didReadData:(NSData *)data withTag:(long)tag {
    
    [viewerSocket readDataToData:separatorData withTimeout:-1 tag:0];
    
    float x, y;
    if ( sscanf( data.bytes, "focus %f %f", &x, &y ) == 2 ) {
        
        [self focusOnPoint:CGPointMake( x, y )];
        
    }
    
    float width, height;
    if ( sscanf( data.bytes, "photo %f %f %f %f", &x, &y, &width, &height ) == 4 ) {
        
        [self switchToPhotoMode];
        [self focusOnPoint:CGPointMake( x + width / 2, y + height / 2 )];
        [self takePhotoAfterAdjustmentDefer:[NSValue valueWithCGRect:CGRectMake( x, y, width, height )]];        
        
    }
    
}

- (void) sendToViewer:(NSData *)data {
    [viewerSocket writeData:data withTimeout:-1 tag:0];
    [viewerSocket writeData:separatorData withTimeout:-1 tag:0];
}

- (CGImageRef) sampleBufferToCGImage:(CMSampleBufferRef)sampleBuffer {
    
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer( sampleBuffer );
    CVPixelBufferLockBaseAddress( imageBuffer, 0 );
    void * buffer = CVPixelBufferGetBaseAddress( imageBuffer );
    size_t bufferSize = CVPixelBufferGetDataSize( imageBuffer );        
    
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow( imageBuffer );
    size_t width = CVPixelBufferGetWidth( imageBuffer );
    size_t height = CVPixelBufferGetHeight( imageBuffer );
    
    CGDataProviderRef dataProvider =
    CGDataProviderCreateWithData( NULL, buffer, bufferSize, NULL );
    CVPixelBufferUnlockBaseAddress( imageBuffer, 0 );
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGImageRef image = CGImageCreate( width, height, 8, 32, bytesPerRow, colorSpace, 
                                     kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder32Little,
                                     dataProvider, NULL, false, kCGRenderingIntentDefault );
    
    CGColorSpaceRelease( colorSpace );
    CGDataProviderRelease( dataProvider );
    
    return image;  
    
}

- (CGImageRef) resizeImageForPreview:(CGImageRef)image {
    
    size_t width = CGImageGetWidth( image );
    size_t height = CGImageGetHeight( image );
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    void * buffer = malloc( ( ( width * IOSCAMERA_PREVIEWSCALE ) * 4 ) * height );
    
    CGContextRef context = 
    CGBitmapContextCreate( buffer, 
                          width * IOSCAMERA_PREVIEWSCALE, 
                          height * IOSCAMERA_PREVIEWSCALE, 
                          8, ( width * IOSCAMERA_PREVIEWSCALE ) * 4,
                          colorSpace, kCGImageAlphaNoneSkipFirst );
    
    CGContextDrawImage( context, 
                       CGRectMake( 0, 0, width * IOSCAMERA_PREVIEWSCALE, height * IOSCAMERA_PREVIEWSCALE ), 
                       image );
    
    CGImageRef resizedImage = CGBitmapContextCreateImage( context );
    
    CGContextRelease( context );
    free( buffer );
    CGColorSpaceRelease( colorSpace );
    
    return resizedImage;
    
}

- (void) captureOutput:(AVCaptureOutput *)captureOutput 
 didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer 
        fromConnection:(AVCaptureConnection *)connection {
    
    if ( !viewerSocket ) {
        return;
    }
    
    if ( !transmitFrame ) {
        transmitFrame = YES;
        return;
    }
    
    CGImageRef image = [self sampleBufferToCGImage:sampleBuffer];
    
    CGImageRef previewImage = [self resizeImageForPreview:image];
    
    NSData * data = UIImageJPEGRepresentation( [UIImage imageWithCGImage:previewImage], 
                                              IOSCAMERA_PREVIEWJPEGQUALITY );
    
    CGImageRelease( image );
    CGImageRelease( previewImage );

    [self sendToViewer:data];
    
    transmitFrame = NO;
    
}

- (void) focusOnPoint:(CGPoint)point {
    [camera lockForConfiguration:nil];
    [camera setFocusPointOfInterest:point];
    [camera setFocusMode:AVCaptureFocusModeAutoFocus];
    [camera setExposurePointOfInterest:point];
    [camera setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
    [camera setWhiteBalanceMode:AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance];
    [camera unlockForConfiguration];
    
    //
    
    if ( !lockAdjustmentTimer ) {
        lockAdjustmentTimer = [NSTimer timerWithTimeInterval:1.0 target:self selector:@selector(lockAdjustment) userInfo:nil repeats:NO];
    }
    if ( [lockAdjustmentTimer isValid] ) {
        [lockAdjustmentTimer invalidate];
    }
    [[NSRunLoop mainRunLoop] addTimer:lockAdjustmentTimer 
                              forMode:NSDefaultRunLoopMode];
}

- (void) lockAdjustment {
    [camera lockForConfiguration:nil];
    [camera setFocusMode:AVCaptureFocusModeLocked];
    [camera setExposureMode:AVCaptureExposureModeLocked];
    [camera setWhiteBalanceMode:AVCaptureWhiteBalanceModeLocked];
    [camera unlockForConfiguration];
}

- (void) takePhotoAfterAdjustmentDefer:(NSValue *)cropRect {
    NSTimer * timer = 
    [NSTimer timerWithTimeInterval:.01 
                            target:self 
                          selector:@selector(takePhotoAfterAdjustment:) 
                          userInfo:cropRect 
                           repeats:NO];
    [[NSRunLoop mainRunLoop] addTimer:timer 
                              forMode:NSDefaultRunLoopMode];
}

- (void) takePhotoAfterAdjustment:(NSTimer *)timer {
    if ( [camera isAdjustingFocus] || 
        [camera isAdjustingExposure] || 
        [camera isAdjustingWhiteBalance] ) {
        
        [self takePhotoAfterAdjustmentDefer:timer.userInfo];
        return;
    }
    
    [self takePhoto:timer.userInfo];
}

- (void) takePhoto:(NSValue *)rectValue {
    CGRect rect = [rectValue CGRectValue];
    
    [photoOutput captureStillImageAsynchronouslyFromConnection:[[photoOutput connections] objectAtIndex:0] 
                                             completionHandler:^(CMSampleBufferRef buffer, NSError * error) {
        
        NSData * data = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:buffer];
        UIImage * image = [UIImage imageWithData:data];
        CGRect croppedRect = 
        CGRectMake( image.size.width * rect.origin.x, image.size.height * rect.origin.y,
                   image.size.width * rect.size.width, image.size.height * rect.size.height );
        
        CGImageRef croppedImage =
        CGImageCreateWithImageInRect( image.CGImage, croppedRect );
        
        NSData * photoData = UIImageJPEGRepresentation( [UIImage imageWithCGImage:croppedImage], 
                                                       IOSCAMERA_PHOTOSCALE );
        
        //
        
        char prefix[] = "photo";
        NSData * prefixData = [NSData dataWithBytes:prefix length:sizeof( prefix )];
        [self sendToViewer:prefixData];
                                                 
        [self sendToViewer:photoData];
        
        //
        
        [self switchToPreviewMode];
        
    }];           
    
}


@end
