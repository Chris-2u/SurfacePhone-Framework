//
//  TouchCursor.m
//  iOS+OFLib
//
//  Created by Christian Winkler on 14.07.13.
//
//

#import "TouchCursor.h"
#import <QuartzCore/QuartzCore.h>

@implementation TouchCursor

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self setBackgroundColor:[UIColor colorWithWhite:0.2 alpha:1.0]];
        [self setClearsContextBeforeDrawing:true];
        showTouchCounter = 0;
        _animateTouch = false;
        self.layer.cornerRadius = frame.size.width/2.0f;
    }
    return self;
}

- (void)setAnimateTouch:(bool)animateTouch {
    _animateTouch = animateTouch;
    showTouchCounter += 30;
}

//- (void)drawRect:(CGRect)rect
//{
//    UIColor *drawColor = _animateTouch ? [UIColor blueColor] : [UIColor yellowColor];
//    CGContextRef ctx = UIGraphicsGetCurrentContext();
//    CGContextAddEllipseInRect(ctx, CGRectMake(_centerX-15, _centerY-15, 30, 30));
//    CGContextSetFillColor(ctx, CGColorGetComponents([drawColor CGColor]));
//    CGContextFillPath(ctx);
//    if (showTouchCounter <= 0)
//        _animateTouch = false;
//    else
//        showTouchCounter--;
//}

@end
