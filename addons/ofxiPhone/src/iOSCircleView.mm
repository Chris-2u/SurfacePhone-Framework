//
//  iOSCircleView.m
//  Drawing Circles with UITouch
//
//  Created by Arthur Knopper on 79//12.
//  Copyright (c) 2012 iOSCreator. All rights reserved.
//

#import "iOSCircleView.h"
#import "iOSCircle.h"
#import "ofxiPhoneViewController.h"

#define RADIUS1 30
#define RADIUS2 50
#define RADIUS3 70


@implementation iOSCircleView


- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        lightgreen = [[UIColor alloc] initWithRed:0.0 green:0.75 blue:0.0 alpha:1.0];
        lightred = [[UIColor alloc] initWithRed:0.75 green:0.0 blue:0.0 alpha:1.0];
        // Initialization code
        totalCircles1 = [[NSMutableArray alloc] init];
        totalCircles2 = [[NSMutableArray alloc] init];
        totalCircles3 = [[NSMutableArray alloc] init];
        gestureCircles = [[NSMutableArray alloc] init];
        
        self.backgroundColor = [UIColor blackColor];
        circleDrawColor = [UIColor whiteColor];
        textDrawColor = [UIColor blackColor];
        [self createCirclesRect:frame];
        currentCircle = 0;
        _isLogEnabled = NO;
    }
    return self;
}


// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    [self drawCircle];
}

- (BOOL)activateNextCircle {
    circleDrawColor = [UIColor whiteColor];
    textDrawColor = [UIColor blackColor];
    currentCircle = currentCircle+1;
    if (currentCircle >= [currentCircles count])
        return false;
    [ofxiPhoneViewController setStudyStatusID:currentCircle AllTargets:[currentCircles count]];
    // update the view
    [self setNeedsDisplay];
    return true;
}
- (void)evaluateTouchPoint:(CGPoint)tp touchStrong:(BOOL) isStrong {
    // get current circle
    iOSCircle* circle = currentCircles[currentCircle];
    // log touch recognition
    // compute distance to touch
    double distance = sqrt(pow((tp.x - circle.circleCenter.x), 2) + pow((tp.y - circle.circleCenter.y), 2));
    bool isInside = distance <= circle.circleRadius;
    // log distance and isInside
    if (_isLogEnabled)
        [self logToFileCircleRadius:circle.circleRadius TargetCenter:circle.circleCenter TouchCenter:tp TouchDistance:distance TouchWithin:isInside TargetStrong:circle.isStrong isStrongTouch:isStrong];
    // visualize
    circleDrawColor = isInside ? [UIColor greenColor] : [UIColor redColor];
    textDrawColor = circle.isStrong == isStrong ? lightgreen : lightred;
    [self setNeedsDisplayInRect:CGRectMake(circle.circleCenter.x-circle.circleRadius, circle.circleCenter.y-circle.circleRadius, circle.circleRadius*2,circle.circleRadius*2)];
}

- (void)evaluateGestureDir:(int)userDir {
    // get current circle
    iOSCircle* circle = currentCircles[currentCircle];
    bool correct = circle.direction == userDir;
    // ONLY FOR VIDEO
//    bool correct = true;
    // log
    if (_isLogEnabled)
        [self logGestureTargetDir:circle.direction UserDir:userDir];
    // visualize
    circleDrawColor = correct ? [UIColor greenColor] : [UIColor redColor];
    [self setNeedsDisplayInRect:CGRectMake(circle.circleCenter.x-circle.circleRadius, circle.circleCenter.y-circle.circleRadius, circle.circleRadius*2,circle.circleRadius*2)];
}

- (void) setFilePath {
    if (logpath == nil) {
        //Get the file path
        NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains (NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
        int i = 0;
        while (true) {
            NSString *fileName = [documentsDirectory stringByAppendingPathComponent: [NSString stringWithFormat:@"log_%d.csv", i++]];
            if(![[NSFileManager defaultManager] fileExistsAtPath:fileName])
            {
                if ([[NSFileManager defaultManager] createFileAtPath:fileName contents:nil attributes:nil]) {
                    logpath = [fileName copy];
                    NSString* content = @"Radius,targetCX,targetCY,touchDX,touchDY,distanceC,insideTarget,targetStrong,touchCorrect,targetGesture,userGesture,gestureCorrect\n";
                    //append text to file
                    NSFileHandle *file = [NSFileHandle fileHandleForUpdatingAtPath:logpath];
                    [file seekToEndOfFile];
                    [file writeData:[content dataUsingEncoding:NSUTF8StringEncoding]];
                    [file closeFile];
                    NSLog(@"Created LOG file %@", logpath);
                } else
                    NSLog(@"Could not create LOG file %@", logpath);
                break;
            }
        }
        [ofxiPhoneViewController setStudyStatusLog:i];
    }
}
- (void) setIsLogEnabled:(BOOL)isLogEnabled {
    _isLogEnabled = isLogEnabled;
    if (!isLogEnabled)
        logpath = nil;
}

- (void)logToFileCircleRadius:(float)radius TargetCenter:(CGPoint)center TouchCenter:(CGPoint)touch TouchDistance:(double)distance TouchWithin:(bool)inside TargetStrong:(BOOL) targetStrong isStrongTouch:(BOOL) touchStrong {
    [self setFilePath];
    NSString *content = [NSString stringWithFormat:@"%f,%f,%f,%f,%f,%f,%d,%d,%d,,\n", radius,center.x,center.y,touch.x-center.x,touch.y-center.y,distance,inside, targetStrong, touchStrong==targetStrong ? 1 : 0];
    
        //append text to file
    NSFileHandle *file = [NSFileHandle fileHandleForUpdatingAtPath:logpath];
    [file seekToEndOfFile];
    [file writeData:[content dataUsingEncoding:NSUTF8StringEncoding]];
    [file closeFile];
}

- (void)logGestureTargetDir:(int)targetDir UserDir:(int)userDir {
    [self setFilePath];
    NSString *content = [NSString stringWithFormat:@",,,,,,,,,%d,%d,%d\n", targetDir, userDir, targetDir==userDir ? 1 : 0];

    //append text to file
    NSFileHandle *file = [NSFileHandle fileHandleForUpdatingAtPath:logpath];
    [file seekToEndOfFile];
    [file writeData:[content dataUsingEncoding:NSUTF8StringEncoding]];
    [file closeFile];
}

- (void)reset {
    currentCircle = 0;
}

- (void)drawCircle
{
    if (currentCircles) {
        // Get the Graphics Context
        CGContextRef context = UIGraphicsGetCurrentContext();
        CGContextSetFillColorWithColor(context, [circleDrawColor CGColor]);
        
        // draw the next target
        //for (iOSCircle* circle in currentCircles) {
        iOSCircle* circle = currentCircles[currentCircle];
        int r = circle.circleRadius;
        CGContextFillPath(context);
        // Create Circle
        CGContextFillEllipseInRect(context, CGRectMake(circle.circleCenter.x - r, circle.circleCenter.y - r, r * 2, r * 2));
        CGContextSetTextDrawingMode(context, kCGTextFill);
        CGContextSelectFont(context, "Arial-BoldMT", 50, kCGEncodingMacRoman);
        CGContextSetTextMatrix(context, CGAffineTransformMake(1.0,0.0, 0.0, -1.0, 0.0, 0.0));
        CGContextSetFillColorWithColor(context, [textDrawColor CGColor]);
        if (currentCircles!=gestureCircles) {
            // Overlay an L for light touch or S for strong touch
            CGContextShowTextAtPoint(context, circle.circleCenter.x-20, circle.circleCenter.y+20, circle.isStrong ? "S" : "L", 1);
        } else {
            string dir;
            switch (circle.direction) {
                case 0:
                    dir = "gesture left";
                    break;
                case 1:
                    dir = "gesture right";
                    break;
                case 2:
                    dir = "gesture up";
                    break;
                case 3:
                    dir = "gesture down";
                    break;
                case 4:
                    dir = "gesture circle";
                default:
                    break;
            }
            CGContextShowTextAtPoint(context, circle.circleCenter.x-160, circle.circleCenter.y+20, dir.c_str(), dir.length());
        }
            
    }
    
}

- (iOSCircle*)createCircleLocation:(CGPoint) location
withRadius:(int) radius forStrongTouch:(BOOL) isStrong
{
    iOSCircle *newCircle = [[iOSCircle alloc] init];
    newCircle.circleCenter = location;
    newCircle.circleRadius = radius;
    newCircle.isStrong = isStrong;
    
    return newCircle;
}
- (iOSCircle*)createCircleLocation:(CGPoint)location withRadius:(int)radius Direction:(int)direction {
    iOSCircle *newCircle = [[iOSCircle alloc] init];
    newCircle.circleCenter = location;
    newCircle.circleRadius = radius;
    newCircle.direction = direction;
    
    return newCircle;
}


- (void)createCirclesRect:(CGRect)frame
                   Target:(NSMutableArray*)targetCircles
                   Radius:(int)r
                   Spacing:(int)spacing
{
    float width = frame.size.width;
    float height = frame.size.height;
    // rectangular area
    
    int numx = 4;
    int numy = 3;
   
    for (int i=0; i<numx; i++) {
        for (int j=0; j<numy; j++) {
            CGPoint p = CGPointMake(i*(2*spacing) + 160 + spacing,
                                    j*(2*spacing) + 90 + spacing);
            [targetCircles addObject:[self createCircleLocation:p withRadius:r forStrongTouch:true]];
            [targetCircles addObject:[self createCircleLocation:p withRadius:r forStrongTouch:false]];
        }
    }

    // update the view
    [self setNeedsDisplay];
}

- (void)createCirclesRect:(CGRect)frame {
    // create collection for each radius
    [self createCirclesRect:frame Target:totalCircles1 Radius:RADIUS1 Spacing:RADIUS2];
    [self createCirclesRect:frame Target:totalCircles2 Radius:RADIUS2 Spacing:RADIUS2];
    [self createCirclesRect:frame Target:totalCircles3 Radius:RADIUS3 Spacing:RADIUS2];
    // gesture
    for (int i=0; i<20; i++) {
        [gestureCircles addObject:[self createCircleLocation:CGPointMake(frame.size.width/2.0,frame.size.height/2.0) withRadius:frame.size.height*0.4 Direction:i%5]];
    }
}

- (void)enableSetNumber:(int)number {
    switch (number) {
        case 1:
            currentCircles = totalCircles1;
            break;
        case 2:
            currentCircles = totalCircles2;
            break;
        case 3:
            currentCircles = totalCircles3;
            break;
        case 4:
            currentCircles = gestureCircles;
            break;
        default:
            currentCircles = nil;
            break;
    }
    [currentCircles shuffle];
    // update the view
    [self setNeedsDisplay];

}



@end
