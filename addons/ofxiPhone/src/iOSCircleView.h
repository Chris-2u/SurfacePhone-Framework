//
//  iOSCircleView.h
//  Drawing Circles with UITouch
//
//  Created by Arthur Knopper on 79//12.
//  Copyright (c) 2012 iOSCreator. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "iOSCircle.h"
#import "NSMutableArray+Shuffling.h"

@interface iOSCircleView : UIControl
{
    NSMutableArray *totalCircles1;
    NSMutableArray *totalCircles2;
    NSMutableArray *totalCircles3;
    NSMutableArray *gestureCircles;

    NSMutableArray *currentCircles;
    
    int currentCircle;
    NSString * logpath;
    UIColor *circleDrawColor;
    UIColor *textDrawColor;
    UIColor * lightgreen;
    UIColor * lightred;
}
@property (nonatomic) BOOL isLogEnabled;

- (void)drawCircle;
- (BOOL)activateNextCircle;
- (void)reset;
- (void)createCirclesRect:(CGRect)frame;
- (void)createCirclesRect:(CGRect)frame
                   Target:(NSMutableArray*)targetCircles
                   Radius:(int)r
                   Spacing:(int)spacing;
- (iOSCircle*)createCircleLocation:(CGPoint) location
                       withRadius:(int) radius;
- (iOSCircle*)createCircleLocation:(CGPoint)location withRadius:(int)radius Direction:(int)direction;
- (void)enableSetNumber:(int)number;
- (void)evaluateTouchPoint:(CGPoint)tp touchStrong:(BOOL) isStrong;
- (void)evaluateGestureDir:(int)userDir;
- (void)logToFileCircleRadius:(float)radius TargetCenter:(CGPoint)center TouchCenter:(CGPoint)touch TouchDistance:(double)distance TouchWithin:(bool)inside TargetStrong:(BOOL) targetStrong isStrongTouch:(BOOL) touchStrong;
- (void) setFilePath;

@end
