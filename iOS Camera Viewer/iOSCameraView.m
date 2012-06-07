#import <OpenGL/OpenGL.h>
#import <QuartzCore/QuartzCore.h>

#import "iOSCameraView.h"


@interface iOSCameraView () {
    
    id <iOSCameraViewDelegate> delegate;
    
    CGImageRef frame;
	GLuint frameTextureId;
    
    NSLock * renderLock;
    NSMutableArray * highlights;
    NSMutableArray * lines;
    NSMutableArray * circles;
    
}
@end


@implementation iOSCameraView


- (id) initWithCoder:(NSCoder *)aDecoder {
    if ( ( self = [super initWithCoder:aDecoder] ) ) {
        
        highlights = [[NSMutableArray array] retain];
        lines = [[NSMutableArray array] retain];
        circles = [[NSMutableArray array] retain];
        
    }
    return self;
}

- (void) setDelegate:(id <iOSCameraViewDelegate>)delegate_ {
    delegate = delegate_;
}

- (void) prepareOpenGL {
    
	glEnable( GL_TEXTURE_2D );
	glGenTextures( 1, &frameTextureId );
    
    glEnable( GL_BLEND );
    glBlendFunc( GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA );
}

- (void) reshape {
    
    const NSSize size = self.bounds.size;
    glViewport( 0, 0, size.width, size.height );
    
    glMatrixMode( GL_PROJECTION );
    glLoadIdentity();
    glOrtho( 0, size.width, size.height, 0, 0, 1 );
    glMatrixMode( GL_MODELVIEW );    
    
}

-(void) setImage:(CGImageRef)image_ {
    
    frame = image_;    
    
	int imageWidth = CGImageGetWidth( frame );
	int imageHeight = CGImageGetHeight( frame );
    
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    GLubyte * data = calloc( imageWidth * imageHeight * 4, sizeof( GLubyte ) );
    CGContextRef context = CGBitmapContextCreate( data, imageWidth, imageHeight, 
                                                 8, imageWidth * 4, colorSpace, 
                                                 kCGBitmapByteOrder32Big | kCGImageAlphaPremultipliedLast );	
	if ( !context ) {
        CGColorSpaceRelease( colorSpace );
        free( data );
        return;
    }
    
    CGContextDrawImage( context, CGRectMake( 0, 0, imageWidth, imageHeight ), frame );
    CGContextRelease( context );
	CGColorSpaceRelease( colorSpace );
	
	glBindTexture( GL_TEXTURE_2D, frameTextureId );
	glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR );
	glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR );
	glTexImage2D( GL_TEXTURE_2D, 0, GL_RGBA, imageWidth, imageHeight, 
                 0, GL_RGBA, GL_UNSIGNED_BYTE, data );
	glBindTexture( GL_TEXTURE_2D, 0 );
	
    free( data );
	
    [self setNeedsDisplay:YES];
    
}

- (void) drawRect:(NSRect)dirtyRect {
    
    CGSize size = self.bounds.size;
    
    glColor4f( 1.0, 1.0, 1.0, 1.0 );
    
    glBindTexture( GL_TEXTURE_2D, frameTextureId );
    glBegin( GL_QUADS );
    
    glTexCoord2f( 0, 1 ); glVertex2f( 0, size.height );
    glTexCoord2f( 1, 1 ); glVertex2f( size.width, size.height );
    glTexCoord2f( 1, 0 ); glVertex2f( size.width, 0 );
    glTexCoord2f( 0, 0 ); glVertex2f( 0, 0 );
    
    glEnd();    
    glBindTexture( GL_TEXTURE_2D, 0 );
    
    for ( NSValue * highlight in highlights ) {
        CGRect highlightRect = [highlight rectValue];
        
        glColor4f( 1.0, 0.0, 0.0, .2 );
        glBegin( GL_QUADS );
        
        glVertex2f( highlightRect.origin.x, 
                   highlightRect.origin.y );
        glVertex2f( highlightRect.origin.x, 
                   highlightRect.origin.y + highlightRect.size.height );
        glVertex2f( highlightRect.origin.x + highlightRect.size.width, 
                   highlightRect.origin.y + highlightRect.size.height );
        glVertex2f( highlightRect.origin.x + highlightRect.size.width, 
                   highlightRect.origin.y );
        
        glEnd();
    }        
        
    glColor4f( 0.0, 1.0, 0.0, .2 );
    glLineWidth( 2 );
    
    for ( NSValue * line in lines ) {
        CGRect lineRect = [line rectValue];
        
        glBegin( GL_LINE_LOOP );
        
        glVertex2f( lineRect.origin.x * 2, 
                   lineRect.origin.y * 2 );
        glVertex2f( ( lineRect.origin.x + lineRect.size.width ) * 2, 
                   ( lineRect.origin.y + lineRect.size.height ) * 2 );
        
        glEnd();
    }        
    
    glColor3f( 0.0, 1.0, 1.0 );
    glLineWidth( 10 );
    
    for ( NSValue * circle in circles ) {
        CGRect circleRect = [circle rectValue];
        
        glBegin( GL_LINE_LOOP ); 
        int segments = 32;
        for ( int i = 0; i < segments; i++ ) { 
            float theta = 2.0f * 3.1415926f * i / segments;
            float x = ( circleRect.size.width * cosf( theta ) );
            float y = ( circleRect.size.width * sinf( theta ) );
            glVertex2f( ( x + circleRect.origin.x ) * 2, ( y + circleRect.origin.y ) * 2 );
        } 
        glEnd(); 
        
    }        
    
    
    [[self openGLContext] flushBuffer];
    
}

- (void) clearHighlights {
    [highlights removeAllObjects];
}

- (void) highlight:(CGRect)rect {
    CGRect adjustedRect = CGRectMake( rect.origin.x * 2, rect.origin.y * 2,
                                     rect.size.width * 2, rect.size.height * 2 );
    [highlights addObject:[NSValue valueWithRect:adjustedRect]];
}

- (void) mouseDown:(NSEvent *)event {
    
    CGPoint point = [self convertPoint:[event locationInWindow] 
                              fromView:nil];
    [delegate cameraView:self didClickPoint:point];
    
    if ( ![highlights count] ) {    
        return;
    }
    
    point.y = self.bounds.size.height - point.y;
    
    for ( NSValue * highlight in highlights ) {
        CGRect highlightRect = [highlight rectValue];
        if ( CGRectContainsPoint( highlightRect, point ) ) {
            
            [delegate cameraView:self didClickHighlight:
             CGRectMake( highlightRect.origin.x / 2, highlightRect.origin.y / 2,
                        highlightRect.size.width / 2, highlightRect.size.height / 2 )];
            break;
            
        }
    }
}

- (void) clearLines {
    [lines removeAllObjects];
}

- (void) line:(CGPoint)source to:(CGPoint)destination {
    [lines addObject:[NSValue valueWithRect:CGRectMake( 
       source.x, source.y, destination.x, destination.y )]];
}

- (void) clearCircles {
    [circles removeAllObjects];
}

- (void) circle:(CGRect)circle {
    [circles addObject:[NSValue valueWithRect:circle]];
}

@end
