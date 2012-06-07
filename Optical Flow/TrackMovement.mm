#import "TrackMovement.h"


@interface TrackMovement () {
    id <TrackMovementDelegate> delegate;
    cv::Mat previousMatrix;
    int framesBetweenProcessing;
}
@end


@implementation TrackMovement


- (void) processImage:(CGImageRef)image {
    
    framesBetweenProcessing++;
    if ( framesBetweenProcessing < 2 ) {
        return;
    }
    
    cv::Mat matrix = [self matrixFromImage:image];
    
    float scale = 6;
    cv::Mat sampleMatrix( matrix.rows / scale, matrix.cols / scale, matrix.type() );
    cv::resize( matrix, sampleMatrix, sampleMatrix.size() );
    
    cv::Mat grayMatrix( sampleMatrix.rows, sampleMatrix.cols, CV_8UC1 );
    cv::cvtColor( sampleMatrix, grayMatrix, CV_BGR2GRAY);
    
    if ( previousMatrix.rows ) {
        
        cv::Mat flowMatrix( sampleMatrix.rows, sampleMatrix.cols, CV_32FC2 );
        
        cv::calcOpticalFlowFarneback( previousMatrix, grayMatrix, flowMatrix, 
             0.5, // pyrScale
             3, // levels
             15, // winsize
             3, // iterations
             5, // polyN
             1.2, // polySigma
             0
        );
        
        [delegate willTrackMovement];
        
        int x, y;
        for ( y = 0; y < sampleMatrix.rows; y++ ) {
            for ( x = 0; x < sampleMatrix.cols; x++ ) {
                [delegate tracked:CGPointMake( x * scale, y * scale ) 
                               to:CGPointMake( flowMatrix.at<cv::Vec2f>( y, x )[ 0 ] * scale, 
                                              flowMatrix.at<cv::Vec2f>( y, x )[ 1 ] * scale )];
            }
        }
    
    }
    
    previousMatrix = grayMatrix;
    
    framesBetweenProcessing = 0;
    
}


//


- (void) setDelegate:(id <TrackMovementDelegate>)delegate_ {
    delegate = delegate_;
}

- (cv::Mat) matrixFromImage:(CGImageRef)image {
    
    CGFloat cols = CGImageGetWidth( image );
    CGFloat rows = CGImageGetHeight( image );
    CGColorSpaceRef colorSpace = CGImageGetColorSpace( image );
    cv::Mat mat( rows, cols, CV_8UC4 );
    
    CGContextRef context = 
    CGBitmapContextCreate( (void *)mat.data,
                          cols, rows, 8,
                          cols * 4, colorSpace, 
                          kCGImageAlphaNoneSkipLast | kCGBitmapByteOrderDefault );
    
    CGContextDrawImage( context, CGRectMake( 0, 0, cols, rows ), image );
    CGContextRelease( context );
    
    return mat;
}


@end
