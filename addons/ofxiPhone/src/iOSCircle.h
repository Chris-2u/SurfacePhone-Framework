//
//  iOSCircle.h
//  Drawing Circles with UITouch
//
//  Created by Arthur Knopper on 79//12.
//  Copyright (c) 2012 iOSCreator. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <CoreGraphics/CGGeometry.h>

@interface iOSCircle : NSObject

@property (nonatomic) CGPoint circleCenter;
@property (nonatomic) float circleRadius;
@property (nonatomic) int counter;
@property (nonatomic) BOOL isStrong;
@property (nonatomic) int direction;

@end
