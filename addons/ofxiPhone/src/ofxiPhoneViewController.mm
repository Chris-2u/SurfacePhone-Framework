//
//  ofxiPhoneViewController.m
//  Created by lukasz karluk on 12/12/11.
//  Modified by Christian Winkler 2013
//

#import "ofxiPhoneViewController.h"
#import "ofxiPhoneExtras.h"
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <NSTimer+Blocks.h>


const int perspectiveTransform = 29;

static iOSCircleView* CircleView;
static UIButton* StartStopButton;
static UISegmentedControl *sizeSelector;
static CGRect screenBounds;
static TouchCursor* touchCursor;
static ofxiPhoneViewController * mSelf;
static UIImageView *calibrationPattern;
static UILabel* StatusLabel;

static UIView* mappingPoints;
static TouchCursor* mapTopLeft;
static TouchCursor* mapTopRight;
static TouchCursor* mapBottomLeft;
static TouchCursor* mapBottomRight;
static UIView* container;
static UIButton * LogButton;

static int statusTargetID = 0, statusTargetAll = 0, statusLogID = 0;

@implementation ofxiPhoneViewController
@synthesize secondWindow;


@synthesize glView;
@synthesize glLock;
@synthesize animTimer;
@synthesize animFrameInterval;
@synthesize animating;
@synthesize displayLinkSupported;
@synthesize displayLink;


+ (id) Instance {
    return mSelf;
}

/////////////////////////////////////////////////
//  INIT.
/////////////////////////////////////////////////

- (id) initWithFrame:(CGRect)frame 
                 app:(ofBaseApp*)app {
    if ((self=[super init])) {

        ofxiPhoneGetAppDelegate().glViewController = self;

        [ self initApp:app ];
        [ self initGLLock ];
        [ self initGLViewWithFrame:frame ];
        [ self initAnimationVars ];
        [ self setupApp ];
        [ self clearBuffers ];
        [ self reloadTextures ];
        [ self startAnimation ];
    }

    [self initScreenWithFrame:frame];
    mSelf = self;
    return self;
}

- (BOOL) isDebugEnabled {
    return _isDebugEnabled;
}

- (void) initScreenWithFrame:(CGRect)frame {
    self.view.backgroundColor = [UIColor blackColor];
   
    StatusLabel = [[UILabel alloc] initWithFrame:CGRectMake(0.0f, 500.0f, 300.0f, 80.0f)];
    StatusLabel.textColor = [UIColor whiteColor];
    StatusLabel.text = @"Status:";
    StatusLabel.backgroundColor = [UIColor blackColor];
    
    StartStopButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    StartStopButton.frame = CGRectMake(0.0f, 0.0f, 100.0f, 30.0f);
    [StartStopButton addTarget:self
                        action:@selector(toggleTest:)
     forControlEvents:UIControlEventTouchUpInside];
    
    [StartStopButton setTitle:@"Start Test" forState:UIControlStateNormal];
    [StartStopButton setTitle:@"Stop Test" forState:UIControlStateSelected];
        
    //Create the segmented control size selector
	NSArray *itemArray = [NSArray arrayWithObjects: @"Small", @"Middle", @"Large", @"Gestures", nil];
	sizeSelector = [[UISegmentedControl alloc] initWithItems:itemArray];
	sizeSelector.frame = CGRectMake(120, 0, 200, 30);
    UIFont *font = [UIFont boldSystemFontOfSize:10.0f];
    NSDictionary *attributes = [NSDictionary dictionaryWithObject:font
                                                           forKey:UITextAttributeFont];
    [sizeSelector setTitleTextAttributes:attributes
                                    forState:UIControlStateNormal];
	sizeSelector.segmentedControlStyle = UISegmentedControlStylePlain;
	sizeSelector.selectedSegmentIndex = 0;
    
    // log button
    LogButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    LogButton.frame = CGRectMake(0.0f, 30.0f, 100.0f, 30.0f);
    [LogButton addTarget:self action:@selector(toggleLog:) forControlEvents:UIControlEventTouchUpInside];
    
    [LogButton setTitle:@"Log disabled" forState:UIControlStateNormal];
    [LogButton setTitle:@"Log enabled" forState:UIControlStateSelected];

    // debug button
    UIButton * DebugButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    DebugButton.selected = true;
    DebugButton.frame = CGRectMake(100.0f, 30.0f, 100.0f, 30.0f);
    [DebugButton addTarget:self action:@selector(toggleDebug:) forControlEvents:UIControlEventTouchUpInside];
    
    [DebugButton setTitle:@"Debug VIS off" forState:UIControlStateNormal];
    [DebugButton setTitle:@"Debug VIS on" forState:UIControlStateSelected];
    
    
    UIButton * ErrorButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    ErrorButton.frame = CGRectMake(200.0f, 30.0f, 100.0f, 30.0f);
    [ErrorButton addTarget:self
                        action:@selector(logError:)
              forControlEvents:UIControlEventTouchUpInside];
    
    [ErrorButton setTitle:@"Log Error" forState:UIControlStateNormal];
    
    [self.view addSubview:StatusLabel];
    
    [self.view addSubview:StartStopButton];

  	[self.view addSubview:sizeSelector];
    
    [self.view addSubview:LogButton];
    
    [self.view addSubview:DebugButton];
    
    [self.view addSubview:ErrorButton];
}

- (void) logError:(id) sender {
    [self onGestureDir:-1];
}

- (void) toggleLog:(id) sender {
    UIButton* button = (UIButton*) sender;
    button.selected = !button.selected;
    [CircleView setIsLogEnabled:button.selected];
}

- (void) toggleDebug:(id) sender {
    UIButton* button = (UIButton*) sender;
    button.selected = !button.selected;
    _isDebugEnabled = button.selected;
}

+ (void) setStudyStatusID:(int) targetID AllTargets:(int) targetAll {
    statusTargetID = targetID;
    statusTargetAll = targetAll;
    [self updateStudyStatus];
}
+ (void) setStudyStatusLog:(int) logID {
    statusLogID = logID;
    [self updateStudyStatus];
}
+ (void) updateStudyStatus {
    StatusLabel.text = [NSString stringWithFormat:@"Target %i/%i, Log %i", statusTargetID+1, statusTargetAll, statusLogID];
}

- (void) enableProjector {
    if ([[UIScreen screens] count] > 1 && secondWindow == nil) {
        
        externalScreen = [[UIScreen screens] objectAtIndex:1];
//        NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains (NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
//        NSString *logFileName = [documentsDirectory stringByAppendingPathComponent: @"videomodes.txt"];
//        [[NSFileManager defaultManager] createFileAtPath:logFileName contents:nil attributes:nil];
        NSString* content = @"";

        // mode handling
        UIScreenMode * pmode = externalScreen.preferredMode;
        NSLog(@"Preferred mode\nWidth %f, Height %f, Ratio %f", pmode.size.width, pmode.size.height, pmode.pixelAspectRatio);
        NSLog(@"Availabe external display modes");
        NSArray * modes = externalScreen.availableModes;
        int i = 0;
        for (UIScreenMode * mode in modes) {
            if (mode.size.width == [UIDevice.currentDevice.name isEqual: @"LondonCalling"] ? 720 : 1600) {
//                [externalScreen setCurrentMode:mode];
//                pmode = mode;
            }
            i++;
            NSLog(@"Width %f, Height %f, Ratio %f", mode.size.width, mode.size.height, mode.pixelAspectRatio);
            content = [content stringByAppendingFormat:@"Width %f, Height %f, Ratio %f\n", mode.size.width, mode.size.height, mode.pixelAspectRatio];
        }
         
//         //append text to file
//         NSFileHandle *file = [NSFileHandle fileHandleForUpdatingAtPath:logFileName];
//         [file seekToEndOfFile];
//         [file writeData:[content dataUsingEncoding:NSUTF8StringEncoding]];
//         [file closeFile];

        // bound are not correctly recognized on iPhone 4
        screenBounds = CGRectMake(0.0f, 0.0f, 720, 480);
        
        secondWindow = [[UIWindow alloc] initWithFrame:screenBounds];
        CGAffineTransform rotateAndScale = CGAffineTransformMakeScale(pmode.size.width / screenBounds.size.width, pmode.size.height / screenBounds.size.height * -1);
//        if (!studySetting)
//            rotateAndScale = CGAffineTransformRotate(rotateAndScale, M_PI);
        [secondWindow setTransform:rotateAndScale];
        
        secondWindow.hidden = false;
        secondWindow.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1.0];
        [secondWindow setScreen:externalScreen];
       
        // CONTAINER WITH PERSPECTIVE TRANSFORM
        container = [[UIView alloc] initWithFrame:screenBounds];
        container.clipsToBounds = true;
        CircleView = [[iOSCircleView alloc] initWithFrame:screenBounds];

        touchCursor = [[TouchCursor alloc] initWithFrame:CGRectMake(0.0, 0.0, 50.0, 50.0)];

        
        // calibration pattern
        calibrationPattern = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"chessboard_6x4 720.png"]];
        [container setFrame:screenBounds];

        [calibrationPattern setContentMode:UIViewContentModeScaleAspectFit | UIViewContentModeCenter | UIViewContentModeRedraw];

        // mapping test points
        mappingPoints = [[UIView alloc] initWithFrame:screenBounds];
        mapTopLeft = [[TouchCursor alloc] initWithFrame:CGRectMake(0, 0, 50, 50)];
        mapTopRight = [[TouchCursor alloc] initWithFrame:CGRectMake(0, 0, 50, 50)];
        mapBottomLeft = [[TouchCursor alloc] initWithFrame:CGRectMake(0, 0, 50, 50)];
        mapBottomRight = [[TouchCursor alloc] initWithFrame:CGRectMake(0, 0, 50, 50)];
        [mappingPoints addSubview:mapTopLeft];
        [mappingPoints addSubview:mapTopRight];
        [mappingPoints addSubview:mapBottomLeft];
        [mappingPoints addSubview:mapBottomRight];
        
        // Add to container
        [container addSubview:calibrationPattern];
        
        [container addSubview:CircleView];
        
        [container addSubview:touchCursor];
        
        [container addSubview:mappingPoints];
        mappingPoints.hidden = true;

        [secondWindow addSubview:container];
        

        // set perspective transform of container layer
        CALayer * transformLayer = container.layer;
        transformLayer.anchorPoint = CGPointMake(0.5, 0.5);
        transformLayer.borderColor = CGColorRef([UIColor blackColor]);
        transformLayer.borderWidth = 5.0f;
        CATransform3D transform = transformLayer.transform;
        transform.m34 = 1.0f / -500.0f;        
        transform = CATransform3DScale(transform, 0.9, 0.9, 1);
        // adjust for bigger projection sizes e.g. iPhone5
//        transform = CATransform3DScale(transform, pmode.size.width / screenBounds.size.width, pmode.size.height / screenBounds.size.height, 1);
        transform = CATransform3DRotate(transform, perspectiveTransform * M_PI/180.0f, 1.0f, 0.0f, 0.0f);
        transform = CATransform3DTranslate(transform, 0.0, -1.5 * 100.0, 0.0);
        transformLayer.transform = transform;

        // start hidden
        [CircleView setHidden:true];
        [touchCursor setHidden:true];
        [calibrationPattern setHidden:true];
        secondWindow.hidden = true;
        
    }
}
- (void) setCalibrationMode:(BOOL)calibrationMode
{
    _calibrationMode = calibrationMode;
    [self enableProjector];
    secondWindow.backgroundColor = calibrationMode ? [UIColor whiteColor] : [UIColor colorWithWhite:0.2 alpha:1.0];;
    [calibrationPattern setHidden:!calibrationMode];
    secondWindow.hidden = !calibrationMode;
}
- (void) setTrackingMode:(BOOL)trackingMode
{
    _trackingMode = trackingMode;
    [self enableProjector];
    [CircleView setHidden:!trackingMode];
    [touchCursor setHidden:!trackingMode];
    secondWindow.backgroundColor = trackingMode ? [UIColor blackColor] : [UIColor colorWithWhite:0.2 alpha:1.0];
    container.layer.borderColor = CGColorRef(trackingMode ? [UIColor whiteColor] : [UIColor blackColor]);
    secondWindow.hidden = !trackingMode;
    // TESTING
//    if (trackingMode) {
//        [sizeSelector setSelectedSegmentIndex:3];
//        [self toggleTest:StartStopButton];
//    }
}
- (void) getProjectionSize:(CGSize&) size {
    size.width = container.frame.size.width;
    size.height = container.frame.size.height;
}

- (BOOL) isGestureEnabled {
    return sizeSelector.selectedSegmentIndex == 3;
}

- (void) showMappingCorners:(vector<CGPoint>)mappingCorners {
    if (mappingCorners.empty())
        mappingPoints.hidden = true;
    else {
        [mapTopLeft setCenter:mappingCorners[0]];
        [mapTopRight setCenter:mappingCorners[1]];
        [mapBottomLeft setCenter:mappingCorners[2]];
        [mapBottomRight setCenter:mappingCorners[3]];
        mappingPoints.hidden = false;
    }
}

- (void) toggleTest:(id)sender {
    NSLog(@"Toggle test");
    UIButton* button = (UIButton*) sender;
    button.selected = !button.selected;
    
    if (button.selected)
        [self startTest];
    else
        [self stopTest];
}

- (void) startTest {
    NSLog(@"start Test");
    [CircleView enableSetNumber:sizeSelector.selectedSegmentIndex+1];
    CircleView.hidden = NO;
    [secondWindow setBackgroundColor: [UIColor blackColor]];
}
- (void) stopTest {
    NSLog(@"stop Test");
    CircleView.hidden = YES;
    [CircleView reset];
    [secondWindow setBackgroundColor:[UIColor grayColor]];
}
- (void) showTouches:(bool) visible {
    [touchCursor setHidden:!visible];
}


- (void) onHoverBlobX:(float)x Y:(float)y {
//    NSLog(@"Projection Hover at %f,%f", x, y);
    
    [touchCursor setCenter:CGPointMake(x,y)];
//    [mSelf->touchCursor setNeedsDisplay];

}
- (void) onTouchBlobX:(float)x Y:(float)y IsStrongTouch:(bool)strong {
    NSLog(@"Projection Touchdown at %f,%f", x, y);

    // do nothing if test is not running
    if (!StartStopButton.selected) return;
    
    // visualize
    [touchCursor setAnimateTouch:true];
    // logic
    // log distance between target and touch position
    // NOTICE: Swap x and y
    [CircleView evaluateTouchPoint:CGPointMake(x,y) touchStrong:strong];
    // activate next circle
    [NSTimer scheduledTimerWithTimeInterval:2.0 target:mSelf selector:@selector(activateNextCircle) userInfo:nil repeats:NO];
}
- (void) onGestureDir:(int)dir {
//    [StatusLabel.text stringByAppendingFormat:@" - Gesture %d", dir];
    [CircleView evaluateGestureDir:dir];
    // activate next circle
    [NSTimer scheduledTimerWithTimeInterval:2.0 target:mSelf selector:@selector(activateNextCircle) userInfo:nil repeats:NO];
}

- (void) activateNextCircle {
    // tell the CircleView to proceed to next circle on UI Thread
    if (![CircleView activateNextCircle]) {
        [self toggleTest:StartStopButton];
    }
}


//NEUENDE'+####################++++++++++++++++++++++###############

//- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
//{
//    return interfaceOrientation == UIInterfaceOrientationLandscapeRight;
//}

- (void) initApp:(ofBaseApp*)app {
    if (ofGetAppPtr()==app)  // app already running.
        return;
    
    ofPtr<ofBaseApp> appPtr;
    appPtr = ofPtr<ofBaseApp>(app);
    ofRunApp(appPtr);
}

- (void) initGLLock {
    self.glLock = [[NSLock alloc] init];
}

- (void) initGLViewWithFrame : (CGRect)frame {
    self.glView = [[EAGLView alloc] initWithFrame:frame
                                          andDepth:iPhoneGetOFWindow()->isDepthEnabled()
                                             andAA:iPhoneGetOFWindow()->isAntiAliasingEnabled() 
                                     andNumSamples:iPhoneGetOFWindow()->getAntiAliasingSampleCount() 
                                         andRetina:iPhoneGetOFWindow()->isRetinaSupported()];
    [self.view insertSubview:self.glView atIndex:0];
}

- (void) initAnimationVars {
    self.animating = YES;
    self.displayLinkSupported = YES;
    self.animFrameInterval = 1;
    self.displayLink = nil;
    self.animTimer = nil;
}

- (void) setupApp {
    ofxiPhoneApp * app;
    app = (ofxiPhoneApp *)ofGetAppPtr();
    
    ofRegisterTouchEvents(app);
    ofxiPhoneAlerts.addListener(app);
    app->setup();
    
    // @julapy - 24/04/2012
    // not sure what the below is supposed to do.
    // it doesn't reach setup() or update().
    // might be some redundant code but will have to double check.
    
#ifdef OF_USING_POCO
    static ofEventArgs voidEventArgs;
    ofNotifyEvent(ofEvents().setup, voidEventArgs);
    ofNotifyEvent(ofEvents().update, voidEventArgs);
#endif
}

- (void) clearBuffers {
    glClearColor(ofBgColorPtr()[0], ofBgColorPtr()[1], ofBgColorPtr()[2], ofBgColorPtr()[3]);   //-- clear background
    glClear( GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
}

- (void) reloadTextures {
    ofUpdateBitmapCharacterTexture();
}

/////////////////////////////////////////////////
//  DEALLOC.
/////////////////////////////////////////////////

- (void) dealloc {
    [self destroy];     //-- destroy in case it hasn't already been done.
    [super dealloc];
}

- (void) destroy {
    //------------------------------------------------------------------- remove controller reference.
    ofxiPhoneGetAppDelegate().glViewController = nil;
    
    //------------------------------------------------------------------- destroy app.
    ofxiPhoneApp * app;
    app = (ofxiPhoneApp *)ofGetAppPtr();
    
    if (app) {
        ofUnregisterTouchEvents(app);
        ofxiPhoneAlerts.removeListener(app);
        app->exit();
    }
    
    ofSetAppPtr(ofPtr<ofBaseApp>((app=NULL)));
    
    //------------------------------------------------------------------- stop animation.
    [self stopAnimation];
    
    //------------------------------------------------------------------- destroy glview.
    [self.glView removeFromSuperview];
    self.glView = nil;
    
    //------------------------------------------------------------------- the rest.
    self.glLock = nil;
}

/////////////////////////////////////////////////
//  UI VIEW CONTROLLER.
/////////////////////////////////////////////////

- (void) viewWillDisappear:(BOOL)animated {
            //[self.view bringSubviewToFront:browser];            //NEU
    [self stopAnimation];
    ofxiPhoneGetAppDelegate().glViewController = nil;
    [super viewWillDisappear:animated];
}

/////////////////////////////////////////////////
//  LOCK / UNLOCK.
/////////////////////////////////////////////////

-(void)lockGL {
	[self.glLock lock];
}

-(void)unlockGL {
	[self.glLock unlock];
}

/////////////////////////////////////////////////
//  ANIMATION TIMER.
/////////////////////////////////////////////////

- (void) timerLoop {
    // tbd
    
    iPhoneGetOFWindow()->timerLoop();
}

- (void)startAnimation {
    if (!self.animating) {
        if (self.displayLinkSupported) {
            // CADisplayLink is API new to iPhone SDK 3.1. Compiling against earlier versions will result in a warning, but can be dismissed
            // if the system version runtime check for CADisplayLink exists in -initWithCoder:. The runtime check ensures this code will
            // not be called in system versions earlier than 3.1.
			
            self.displayLink = [NSClassFromString(@"CADisplayLink") displayLinkWithTarget:self selector:@selector(timerLoop)];
            self.animFrameInterval = 2;
            [self.displayLink setFrameInterval:self.animFrameInterval];
            [self.displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
			ofLog(OF_LOG_VERBOSE, "CADisplayLink supported, running with interval: %i", self.animFrameInterval);
        }
        else {
			ofLog(OF_LOG_VERBOSE, "CADisplayLink not supported, running with interval: %i", self.animFrameInterval);
            self.animTimer = [NSTimer scheduledTimerWithTimeInterval:(NSTimeInterval)((1.0/60.0)*self.animFrameInterval)
                                                              target:self 
                                                            selector:@selector(timerLoop)
                                                            userInfo:nil 
                                                             repeats:TRUE ];
		}
		
        self.animating = TRUE;
    }
}

- (void)stopAnimation {
    if (self.animating) {
        if (self.displayLinkSupported) {
            [self.displayLink invalidate];
            self.displayLink = nil;
        }
        else {
            [self.animTimer invalidate];
            self.animTimer = nil;
		}
		
        self.animating = FALSE;
    }
}

- (void)setAnimationFrameInterval:(float)frameInterval {
    // Frame interval defines how many display frames must pass between each time the
    // display link fires. The display link will only fire 30 times a second when the
    // frame internal is two on a display that refreshes 60 times a second. The default
    // frame interval setting of one will fire 60 times a second when the display refreshes
    // at 60 times a second. A frame interval setting of less than one results in undefined
    // behavior.
    if (frameInterval >= 1) {
        self.animFrameInterval = frameInterval;
		
        if (self.animating) {
            [self stopAnimation];
            [self startAnimation];
        }
    }
}

-(void) setFrameRate:(float)rate {
	ofLog(OF_LOG_VERBOSE, "setFrameRate %.3f using NSTimer", rate);
	
	if(rate>0) [self setAnimationFrameInterval:60.0/rate];
	else [self stopAnimation];
}

@end
