//
//  ofxiPhoneViewController.h
//  Created by lukasz karluk on 12/12/11.
//

#import <UIKit/UIKit.h>
#import "EAGLView.h"
#import "iOSCircleView.h"
#import "TouchCursor.h"

void ofPauseVideoGrabbers();
void ofResumeVideoGrabbers();
void ofReloadAllImageTextures();
void ofUnloadAllFontTextures();
void ofReloadAllFontTextures();
void ofUpdateBitmapCharacterTexture();

static BOOL _isDebugEnabled = false;

@interface ofxiPhoneViewController : UIViewController {
    // device screen
    UIWindow *secondWindow;
    UIScreen *externalScreen;
    
    //UILabel * StatisticsLabel;
    //UIButton * StartStopButton;
    
    NSConditionLock* openViewLock;
    
    // external
//    iOSCircleView * CircleView;
}
//neu#####################
@property (strong, nonatomic) UIWindow *window;
@property (nonatomic, retain) IBOutlet UIWindow *secondWindow;

//ENDNEU#####################
@property (nonatomic, retain) EAGLView* glView;
@property (nonatomic, retain) NSLock* glLock;
@property (nonatomic, retain) NSTimer* animTimer;
@property (nonatomic, assign) float animFrameInterval;
@property (nonatomic, assign) BOOL animating;
@property (nonatomic, assign) BOOL displayLinkSupported;
@property (nonatomic, assign) id displayLink;
@property (nonatomic, assign) BOOL calibrationMode;
@property (nonatomic, assign) BOOL trackingMode;


+ (id) Instance;

- (BOOL) isDebugEnabled;
- (BOOL) isGestureEnabled;
- (id) initWithFrame:(CGRect)frame 
                 app:(ofBaseApp*)app;
- (void) enableProjector;
- (void) initApp:(ofBaseApp*)app;
- (void) initGLLock;
- (void) initGLViewWithFrame:(CGRect)frame;
- (void) initAnimationVars;
- (void) setupApp;
- (void) clearBuffers;
- (void) reloadTextures;

- (void) lockGL;
- (void) unlockGL;

- (void) timerLoop;

- (void) stopAnimation;
- (void) startAnimation;

- (void) setAnimationFrameInterval:(float)frameInterval;
- (void) setFrameRate:(float)frameRate;

- (void) destroy;

- (void) toggleTest:(id)sender;
- (void) startTest;
- (void) stopTest;
- (void) showTouches:(bool) visible;
- (void)onTouchBlobX:(float)x Y:(float)y IsStrongTouch:(bool)strong;
- (void) onHoverBlobX:(float)x Y:(float)y;
- (void) activateNextCircle;
- (void) showMappingCorners:(vector<CGPoint>)mappingCorners;
- (void) getProjectionSize:(CGSize&) size;
+ (void) setStudyStatusLog:(int) logID;
+ (void) setStudyStatusID:(int) targetID AllTargets:(int) targetAll;
+ (void) updateStudyStatus;
- (void) toggleLog:(id) sender;
- (void) toggleDebug:(id) sender;
- (void) onGestureDir:(int)dir;
- (void) logError:(id) sender;

@end
