//
//  TouchCursor.h
//  iOS+OFLib
//
//  Created by Christian Winkler on 14.07.13.
//
//

#import <UIKit/UIKit.h>

@interface TouchCursor : UIView {
    @private
    int showTouchCounter;
}


@property (nonatomic) bool animateTouch;

@end
