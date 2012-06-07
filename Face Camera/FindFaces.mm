#import "FindFaces.h"


#define FACE_X_PADDING .3
#define FACE_Y_PADDING .9


@interface FindFaces() {
    id <FindFacesDelegate> delegate;
    cv::CascadeClassifier cascadeClassifier;
}
@end


@implementation FindFaces

- (id) init {
    if ( ( self = [super init] ) ) {
        
        char path[ PATH_MAX ] = "";
        snprintf( path, sizeof( path ) - 1, "%s/../%s",
                 __FILE__, "haarcascade_frontalface_alt2.xml" );
        
        cascadeClassifier.load( realpath( path, 0 ) );
         
    }
    return self;
}

- (void) detect:(CGImageRef)image {
    
    cv::Mat matrix = [self matrixFromImage:image];
    cv::vector< cv::Rect > faces;
    
    cascadeClassifier.detectMultiScale( matrix, faces );
    
    
    [delegate findFacesDidDetect];    
    
    
    cv::vector< cv::Rect >::const_iterator face;
    
    for ( face = faces.begin(); face != faces.end(); face++ ) { 
        
        [delegate findFacesFound:
         CGRectMake( face->x - ( face->width * ( FACE_X_PADDING / 2 ) ), 
                    face->y - ( face->height * ( FACE_Y_PADDING / 2 ) ), 
                    face->width + ( face->width * FACE_X_PADDING ), 
                    face->height + ( face->height * FACE_Y_PADDING ) )];
        
    }
    
}


//


- (void) setDelegate:(id <FindFacesDelegate>)delegate_ {
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
