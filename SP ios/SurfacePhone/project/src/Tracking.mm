/*
 *  SurfacePhone Framework by Christian Winkler (cwinkler.eu@gmail.com)
 *  As used in http://dx.doi.org/10.1145/2556288.2557075 (requires ACM access) or http://uulm.de?SurfacePhone
 *  
 *  The system supports touch and gesture recognition on the projected surface
 *  as well as a study and logging application to test for these capabilities.
 *
 *  The interesting files you might want to alter are:
 *  This file                   for general application flow, vibration and camera tracking
 *  OfxiPhoneViewController     for all view related things regarding iPhone or projected display
 *  Gestures.json               for supported gestures (see 1$ gesture recognizer)
 *
 *  For steps 1 and 2 camera parameter calibration files will be placed in the app folder upon success.
 *  For the first step you have to print chessboard_6x4 720.png, but you can alter settings.yml to play with alternatives.
 *  If calibration does not work for you, you find good calibrations in the root folder that you can copy to the app using iTunes.
 *
 *  Licensed under MIT License (see root folder).
 */

#include "Tracking.h"
#include "ChessCalibration.h"
#include "ofxCv.h"
#import <NSTimer+Blocks.h>
#import <AVFoundationVideoGrabber.h>
#import <AudioToolbox/AudioToolbox.h>
#import "GLGestureRecognizer.h"
#import "GLGestureRecognizer+JSONTemplates.h"

void RUN_ON_UI_THREAD(dispatch_block_t block)
{
    if ([NSThread isMainThread])
        block();
    else
        dispatch_sync(dispatch_get_main_queue(), block);
}

// TOUCH RECOGNITION
#define TOUCH_n 15 // moving recognition window 15 Hz
// Whether the system should recalibrate the threshholds based on vibration patterns it sends out
// since iOS7 the private API that was used for implementation does no longer exist so the pattern
// became less usable (see commented code at the end)
#define CALIBRATE_SURFACE false

static float TOUCH_SOFT_SURFACE_AVG = 0.01f;
static float TOUCH_ROBUST_SURFACE_AVG = 0.05f;
static float TOUCH_THRESHOLD = 0.009f; // threshold for soft touch
static float STRONG_TOUCH_THRESHOLD = 1.5 * TOUCH_THRESHOLD; // threshold for strong touch

static int touchCounter = 0;
static int strongTouchCounter = 0;

// wether the accelerometer should be calibrated as soon as the app starts
static BOOL calibrateAcc = YES;
static int calibrateSurfaceCounter = CALIBRATE_SURFACE ? 180 : 0;
static float zeroAcceleration = 9.8f;
static float touchSurfaceAvg = 0.0f;
static volatile BOOL recognizeTouches = true;
static volatile int touchRecognized = 0;

static Tracking * mThis;
static float* lastAcc;
const int accsize = 10;
static int lastAccCounter = 0;
static NSMutableArray *fingerHistoryX;
static NSMutableArray *fingerHistoryY;

static ChessCalibration* calibration;

static GLGestureRecognizer* recognizer;

//static volatile double lastTouch = 0.0;
//static volatile double lastTouchExecuted = 0.0;

static ofPoint activeDistanceMoved;
static ofPoint previousActiveFingerPosition;

// BLOB RECOGNITION
float minBlobsize;
float maxBlobsize;

const int fingerThreshold = HUEbased ? 75 : 75;
const int fingerHistorySize = 5;
static int activeBlobId = 0;

int showFocusCalibration = 0;
int showMappingCalibration = 0;
bool mappingCalibration = false;

CGSize projectionSize = CGSizeMake(720, 480);

enum SystemStates {
    INIT,
    CAMERA_CALIBRATION_INTRINSICS,
    CAMERA_CALIBRATION_EXTRINSICS,
    FINGER_CALIBRATION,
    TRACKING
};
SystemStates systemstate;


void Tracking::setup(){
	mThis = this;
    iPhoneSetOrientation(OFXIPHONE_ORIENTATION_LANDSCAPE_LEFT);
    // INIT
    systemstate = INIT;
    ofLog(OF_LOG_NOTICE, "STEP 1: Init camera");
    initCamera();
    viewController = [[ofxiPhoneViewController alloc] init];

    // INTRINSICS
    systemstate = CAMERA_CALIBRATION_INTRINSICS;
    ofLog(OF_LOG_NOTICE, "STEP 2: Try to load intrinsic camera parameters");
	if (calibration->loadIntrinsics()) {
        ofLog(OF_LOG_NOTICE, "STEP 2: Intrinsics loaded from file");
    }
    else {
        ofLog(OF_LOG_NOTICE, "STEP 2: Intrinsics not found. Starting calibration");
        return;
    }
    // EXTRINSICS
    systemstate = CAMERA_CALIBRATION_EXTRINSICS;
    ofLog(OF_LOG_NOTICE, "STEP 3: Try to load extrinsic camera parameters");
	if (!calibration->loadExtrinsics()) {
        ofLog(OF_LOG_NOTICE, "STEP 3: Extrinsics not found. Starting calibration");
        [viewController setCalibrationMode:true];
        return;
    }
    // Extrinsics loaded from file > enable Chessboard to evaluate mapping
    [viewController setCalibrationMode:true];
    // Wait for finger calibration
    systemstate = FINGER_CALIBRATION;
    
    calibration->testReprojection();

    //    showFocusCalibration = 80;
//    [NSTimer scheduledTimerWithTimeInterval:0.1 block:^(void){fingerTestDriver();} repeats:YES];
}

void Tracking::initCamera() {
    capW = 640.0;
	capH = 480.0;
    
//    if ([UIDevice.currentDevice.name isEqual: @"LondonCalling"]) {
//        capW = 352.0;
//        capH = 288.0;
//    }
    
    int inputFramerate = 25;
    minBlobsize = 20;
    maxBlobsize = capW*capH / 6.0;
    
    vidGrabber.setDesiredFrameRate(inputFramerate);
    vidGrabber.initGrabber(capW, capH);
    
    capW = vidGrabber.getWidth();
    capH = vidGrabber.getHeight();
    
    NSLog(@"Video initialised to %f width, %f height @ %i FPS", capW, capH, inputFramerate);
    
    // Alloc image memory
    colorImg.allocate(capW,capH);
    previousImg.allocate(capW, capH);
    grayImage.allocate(capW,capH);
    grayBg.allocate(capW,capH);
    grayDiff.allocate(capW,capH);
    
    fingerHistoryX = [[NSMutableArray alloc] init];
    fingerHistoryY = [[NSMutableArray alloc] init];
    // settings
	
	ofSetFrameRate(2.0);
    
    // prepare calibration
    NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains (NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString *calibrationFileName = [documentsDirectory stringByAppendingPathComponent: @""];
    calibration = new ChessCalibration();
    calibration->setup(colorImg.getCvImage(), *new string(calibrationFileName.UTF8String));
}

float fingerDriverX = 1000;
float fingerDriverY = 1000;
void Tracking::fingerTestDriver() {
    if (fingerDriverX>=calibration->imagePoints[calibration->imagePoints.size()-1].x) {
        fingerDriverX = calibration->imagePoints[0].x;
        fingerDriverY = calibration->imagePoints[0].y;
    }
    cv::Point2f point = cv::Point2f(fingerDriverX,fingerDriverY);
    calibration->transformImgToObjPoint(point);
    //    NSLog(@"Point mapping from %i,%i to %f,%f", fingerDriverX, fingerDriverY, point.x, point.y);
    RUN_ON_UI_THREAD(^{
        [viewController showTouches:true];
    });
    fireFingerEvent(point.x, point.y);
    fingerDriverX += (calibration->imagePoints[calibration->imagePoints.size()-1].x-calibration->imagePoints[0].x)/50.0;
    fingerDriverY += (calibration->imagePoints[calibration->imagePoints.size()-1].y-calibration->imagePoints[0].y)/50.0;
    
}

void Tracking::startTouchTracking() {
    if (!calibrateAcc) return;
    ofxAccelerometer.setup();
    ofxAccelCB cb = Tracking::accelChanged;
    ofxAccelerometer.setCallback(cb);
    
    //    ofxAccelerometer.setForceSmoothing(0.0f);
    lastAcc = new float[accsize];
    emptyAcc();
    
//    opFlow.setup(capW,capH);
    
    recognizer = [[GLGestureRecognizer alloc] init];
    
	NSData *jsonData = [NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Gestures" ofType:@"json"]];
    
	BOOL ok;
	NSError *error;
	ok = [recognizer loadTemplatesFromJsonData:jsonData error:&error];
	if (!ok)
	{
		NSLog(@"Error loading gestures: %@", error);
		return;
	}
    
    [viewController getProjectionSize:projectionSize];
    
    ofAddListener(blobTracker.blobAdded, this, &Tracking::blobAdded);
    ofAddListener(blobTracker.blobMoved, this, &Tracking::blobMoved);
    ofAddListener(blobTracker.blobDeleted, this, &Tracking::blobDeleted);
    
    // start for calibration
    ofxAccelerometer.start();
}

void Tracking::emptyAcc() {
    for (int i=0; i<accsize; i++)
        lastAcc[i] = zeroAcceleration;
    lastAccCounter = 0;
}
float Tracking::avgAcc() {
    float sum = 0;
    for (int i=0; i<accsize; i++)
        sum += lastAcc[i];
    return sum/accsize;
}
float Tracking::maxAcc() {
    float max = -100000.0;
    for (int i=0; i<accsize; i++) {
        if (lastAcc[i]>max)
            max = lastAcc[i];
    }
    return max;
}
float Tracking::minAcc() {
    float min = 100000.0;
    for (int i=0; i<accsize; i++) {
        if (lastAcc[i]<min)
            min = lastAcc[i];
    }
    return min;
}

void Tracking::accelChanged(ofPoint &point) {
    // CALIBRATION
    float rawAcc = -point.x;
    
    if (calibrateAcc) {
        if (lastAccCounter == accsize) {
            calibrateAcc = NO;
            zeroAcceleration = avgAcc();
            emptyAcc();
            NSLog(@"TOUCH - Calibrated to %f m/s", zeroAcceleration);
            // now do surface calibration by initiating an own vibration
            if (CALIBRATE_SURFACE) {
                AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
                NSLog(@"Vibrate");
            }
            
        } else
           lastAcc[lastAccCounter++] = rawAcc;
        return;
    }
    if (!recognizeTouches) {
        emptyAcc();
        return;
    }
    
    lastAcc[lastAccCounter++] = rawAcc;
    if (lastAccCounter==accsize) {
        lastAccCounter = 0;

    }
    // RECOGNITION

    int touch = 0; // 1 touch, 2 strong touch
    // walk trough history of values and compare acceleration against zero
    // and add this to differences

    float posMax = maxAcc();
    float negMax = minAcc();
    float sum = posMax -negMax;
    
    if (calibrateSurfaceCounter > 0) {
        touchSurfaceAvg += sum;
        if (calibrateSurfaceCounter == 1) {
            touchSurfaceAvg /= 180;
            NSLog(@"Surface Avg %f", touchSurfaceAvg);
            // adjust touch thresholds
            TOUCH_THRESHOLD /= (touchSurfaceAvg - TOUCH_SOFT_SURFACE_AVG) / (TOUCH_ROBUST_SURFACE_AVG - TOUCH_SOFT_SURFACE_AVG) * 1.35f;
            STRONG_TOUCH_THRESHOLD = (1.75f - TOUCH_SOFT_SURFACE_AVG) * TOUCH_THRESHOLD;
        }
        calibrateSurfaceCounter--;
    }

    if (touch==0 && sum > STRONG_TOUCH_THRESHOLD) {
        strongTouchCounter++;
        if (strongTouchCounter == TOUCH_n) {
            NSLog(@"STRONG Touch");
            touch = 2;
        }
    } else {
        strongTouchCounter = 0;
    }
    if (touch==0 && sum > TOUCH_THRESHOLD) {
        touchCounter++;
        if (touchCounter == TOUCH_n) {
            NSLog(@"Touch");
            touch = 1;
        }
    } else {
        touchCounter = 0;
    }
    // EXECUTION
    // if we have a touch and a finger position take the recent avg and call onTouch
    if (touch>0) {

//        float avgX = [[fingerHistoryX valueForKeyPath:@"@avg.self"] floatValue];
//        float avgY = [[fingerHistoryY valueForKeyPath:@"@avg.self"] floatValue];
//        cv::Point2f avgPoint = cv::Point2f(avgX*mThis->capW,avgY*mThis->capH);
//        calibration->transformImgToObjPoint(avgPoint);
//        mThis->fireFingerEvent(avgPoint.x, avgPoint.y, touch);

        recognizeTouches = false;
        touchRecognized = touch;
        // reset
        touchCounter = 0;
        strongTouchCounter = 0;
        
        RUN_ON_UI_THREAD(^{
            mThis->timeoutTouchRecognition();
        });
    }

}

void Tracking::timeoutTouchRecognition() {
    recognizeTouches = false;
    [NSTimer scheduledTimerWithTimeInterval:1.5 block:^(void){
        recognizeTouches=true;
        if (calibrateSurfaceCounter > 0) {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
            NSLog(@"Vibrate");
        }
    } repeats:NO];
}


//--------------------------------------------------------------
void Tracking::update(){
    // try to grab new frame
    vidGrabber.update();
    // if there is no new frame, skip detection
    if (vidGrabber.isFrameNew()){
//		if( vidGrabber.getPixels() != NULL ){
        colorImg.setFromPixels(vidGrabber.getPixels(), capW, capH);
        cv::Mat distorted;
        cv::Mat undistorted;
        cv::Mat remapped;
            switch (systemstate) {
                case CAMERA_CALIBRATION_INTRINSICS:
                    if (calibration->updateIntrinsics()) {
                        cout << "STEP1: Intrinsics saved!" << endl;
                            [viewController setCalibrationMode:true];
                        systemstate = SystemStates(systemstate+1);
                    }
                    break;
                case CAMERA_CALIBRATION_EXTRINSICS:
//                    colorImg.convertRgbToHsv();
//                    colorImg.convertToGrayscalePlanarImage(grayImage, 1); // take brightness channel
                    distorted = cv::Mat(colorImg.getCvImage());
                    cv::addWeighted(cv::Mat(colorImg.getCvImage()), 0.5, cv::Mat(previousImg.getCvImage()), 0.5, 0.0, distorted);
                        distorted.convertTo(distorted, -1, 1.5, -50);
                    if (!calibration->found && calibration->updateExtrinsics()) {
                        cout << "STEP2: Extrinsics saved!" << endl;
                        calibration->testReprojection();
                        [NSTimer scheduledTimerWithTimeInterval:4.0 block:^(void) {
                        systemstate = SystemStates(systemstate+1);
                            [NSTimer scheduledTimerWithTimeInterval:4.0 block:^(void) {
                                [viewController setCalibrationMode:false];
                            } repeats:NO];
                        } repeats:NO];
                    } else {
                        previousImg = colorImg;
                    }
                    break;
                case FINGER_CALIBRATION:
                    grayImage = colorImg;
                    distorted = cv::Mat(grayImage.getCvImage());
                    undistorted = cv::Mat(grayBg.getCvImage());
                    calibration->calibration.undistort(distorted, undistorted);
                    grayBg.flagImageChanged();
                    calibration->transformImageExtrinsic(grayImage.getCvImage(), grayDiff.getCvImage());
                    grayDiff.flagImageChanged();
                    break;
                case TRACKING:
                    if (calibrateSurfaceCounter > 0)break;
                    // we use the HUE channel of HSV color model for background substraction
                    // to eliminate shadows
                    // then we undistort in the calibrated space and run blob tracking on that
                    colorImg.convertRgbToHsv();
                    colorImg.convertToGrayscalePlanarImage(grayImage, HUEbased ? 0 : 1); // take saturation channel
                    calibration->transformImageExtrinsic(grayImage.getCvImage(), grayBg.getCvImage());
                    grayBg.flagImageChanged();

                    grayDiff = grayBg;
                    blobTracker.update(grayDiff, fingerThreshold, minBlobsize, maxBlobsize, 10, 1);
                    if (blobTracker.size()>0) {
                        if (!blobTracker[0].fingers.empty()) {
                            activeBlobId = blobTracker[0].id;
//                            if ([fingerHistoryX count]==fingerHistorySize) {
//                                [fingerHistoryX removeObjectAtIndex:0];
//                                [fingerHistoryY removeObjectAtIndex:0];
//                            }
//                            [fingerHistoryX addObject:[NSNumber numberWithFloat:blobTracker[0].fingers[0].x]];
//                            [fingerHistoryY addObject:[NSNumber numberWithFloat:blobTracker[0].fingers[0].y]];
//                            float avgX = [[fingerHistoryX valueForKeyPath:@"@avg.self"] floatValue];
//                            float avgY = [[fingerHistoryY valueForKeyPath:@"@avg.self"] floatValue];
//                            cv::Point2f avgPoint = cv::Point2f(
//                                                               avgX*capW,
//                                                               avgY*capH);
                            if ([viewController isGestureEnabled]) {
//                                [recognizer addTouchAtPoint:CGPointMake(blobTracker[0].fingers[0].x, blobTracker[0].fingers[0].y)];
                            } else {
                                fireFingerEvent(blobTracker[0].fingers[0].x, blobTracker[0].fingers[0].y, touchRecognized);
                                touchRecognized = 0;
                            }
                        }
                    }
                    break;
                default:
                    break;
            }
        distorted.release();
        undistorted.release();
        remapped.release();
//   		}
	}
}

void Tracking::fireFingerEvent(float x, float y, int touch) {
    // here we get undistorted objects points in normed camera space
    // transform to absolute coordinates on the projector
    
    // stretch around center
    x = (x - 0.5) * calibration->scaleFactor + 0.5;
    y = (y - 0.5/(640/480)) * calibration->scaleFactor + 0.5/(640/480);
    // map to target space
    x = x * 720;
    y = y * 480;
    // add finger offset
    x = x+10;
    y = y+50; //1.1+20;
    
    RUN_ON_UI_THREAD(^(void) {
        if (touch==0)
//            [viewController onHoverBlobX:x Y:y];
            ;
        else
            [viewController onTouchBlobX:x Y:y IsStrongTouch:touch==2];
    });
}

void Tracking::blobAdded(ofxBlob &_blob) {
    // listen for touch events
    // as we only track the biggest blob, a new blob means that
    // we have to begin a new history of fingers
//    [fingerHistoryX removeAllObjects];
//    [fingerHistoryY removeAllObjects];
//    ofxAccelerometer.start();
    // and add the blobs fingers as first history element
//    if (_blob.gotFingers) {
//        [fingerHistoryX addObject:[NSNumber numberWithFloat:_blob.fingers[0].x]];
//        [fingerHistoryY addObject:[NSNumber numberWithFloat:_blob.fingers[0].y]];
//    }
//    NSLog(@"blob added");
    touchRecognized = 0;
    activeDistanceMoved.set(0, 0);
    previousActiveFingerPosition.set(-1, -1);
    [recognizer resetTouches];
//    RUN_ON_UI_THREAD(^{
//        [viewController showTouches:true];
//    });
}
void Tracking::blobMoved(ofxBlob &_blob) {
    if ([viewController isGestureEnabled] && _blob.gotFingers) {
        // only take movements that are within 75% center area
        if (_blob.fingers[0].x > 0.2 && _blob.fingers[0].x < 0.8
            && _blob.fingers[0].y > 0.2 && _blob.fingers[0].y < 0.8) {
            if (previousActiveFingerPosition.x > -1) {
                activeDistanceMoved += _blob.fingers[0] - previousActiveFingerPosition;
//                NSLog(@"Distance %f,%f", activeDistanceMoved.x, activeDistanceMoved.y);
                [recognizer addTouchAtPoint:CGPointMake(_blob.fingers[0].x, _blob.fingers[0].y)];
            }
            previousActiveFingerPosition.set(_blob.fingers[0]);
        }
    }
}
void Tracking::blobDeleted(ofxBlob &_blob) {

//    ofxAccelerometer.stop();
//    [fingerHistoryX removeAllObjects];
//    [fingerHistoryY removeAllObjects];
//        NSLog(@"blob deleted");
        if ([viewController isGestureEnabled])
            processGestureData();
//        RUN_ON_UI_THREAD(^{
//            [viewController showTouches:false];
//        });
}

void Tracking::processGestureData()
{
    CGPoint center;
	float score, angle;
    int diri = -1;
	NSString *gestureName = [recognizer findBestMatchCenter:&center angle:&angle score:&score];
    if ([gestureName isEqual:@"circle"]) {
        NSLog(@"gesture circle");
        diri = 4;
      	NSLog(@"%@ %f", gestureName, score);
    } else {
        bool tooShort = false;
        if (abs(activeDistanceMoved.x) > abs(activeDistanceMoved.y)*1.33) {
            // horizontal
            diri = activeDistanceMoved.x < 0 ? 0 : 1;
            if (abs(activeDistanceMoved.x) < 0.25)
                tooShort = true;
        } else {
            // vertical
            diri = activeDistanceMoved.y < 0 ? 2 : 3;
            if (abs(activeDistanceMoved.y) < 0.25)
                tooShort = true;
        }
        switch (diri) {
            case 0:
                gestureName = @"gesture left";
                break;
            case 1:
                gestureName = @"gesture right";
                break;
            case 2:
                gestureName = @"gesture up";
                break;
            case 3:
                gestureName = @"gesture down";
                break;
            default:
                break;
        }
        if (tooShort)
            diri = -1;
    }
    if (diri > -1) {
        NSLog(@"GESTURE %@", gestureName);
        [viewController onGestureDir:diri];
    }

}


void Tracking::draw(){
    ofBackground(0, 0, 0);
    char reportStr[1024];
    ofSetColor(255);
    int lb = 130;
    float fps;
    switch (systemstate) {
        case CAMERA_CALIBRATION_INTRINSICS:
            colorImg.draw(lb,0,480,360);
            calibration->drawIntrinsics();
            sprintf(reportStr, "STEP 1: Intrinsics Calibration");
            break;
        case CAMERA_CALIBRATION_EXTRINSICS:
            calibration->drawExtrinsics();
            colorImg.draw(lb,0,480,360);
            sprintf(reportStr, "STEP 2: Extrinsics Calibration");
            break;
        case FINGER_CALIBRATION:
            grayImage.draw(lb,0,320,240);
            if (showFocusCalibration > 0) {
                cameraFingerCalibration();
            } else {
                grayBg.draw(lb+320,0,320,240);
                grayDiff.draw(lb,240, 320, 240);
                sprintf(reportStr, "STEP 3: Touch screen to start finger calibration");
            }
            break;
        case TRACKING:
            if ([viewController isDebugEnabled])
            {

                // original remapped image
                grayBg.draw(lb,0,320,240);
                // background image
                blobTracker.backgroundImage.draw(lb,240,320,240);
                grayDiff.draw(lb+320, 0, 480, 360);
                if (blobTracker.size()>0) {
                    blobTracker.draw(lb+320, 0, 480, 360);
                }
            }
            fps = ofGetFrameRate();
            sprintf(reportStr, "TRACKING: blob detection, touch screen to recapture finger\nthreshold %i, num blobs found %i, fps: %f", fingerThreshold, blobTracker.size(), fps);
            if (fps < 17.0) {
                AudioServicesPlaySystemSound(1073);
            }
            break;
        default:
            break;
    }
    ofSetHexColor(0xffffff);
    ofPushMatrix();
    ofScale(1.5, 1.5);
    ofDrawBitmapString(reportStr, 100, 400);
    ofPopMatrix();
}

void Tracking::cameraFingerCalibration() {
    string msg;

    if (showFocusCalibration > 60) {
        if (showFocusCalibration==80) {
            RUN_ON_UI_THREAD(^(void) {
                [viewController setCalibrationMode:false];
                [viewController setTrackingMode:false];
            });
            ofiPhoneVideoGrabber * grabber = dynamic_cast<ofiPhoneVideoGrabber*> (&*vidGrabber.getGrabber());
            [grabber->grabber->grabber  lockExposureAndFocus:false];
        }
        msg = "Present your finger\nto the center of the camera";
    } else if (showFocusCalibration > 15) {
        msg = "Quickly remove your finger";
        if (showFocusCalibration == 40) {
            RUN_ON_UI_THREAD(^{
                [viewController setTrackingMode:true];
            });
            // adjust camera focus and exposure
            ofiPhoneVideoGrabber * grabber = dynamic_cast<ofiPhoneVideoGrabber*> (&*vidGrabber.getGrabber());
            [grabber->grabber->grabber  lockExposureAndFocus:true];
            // wait for the user to take out their finger
            // reset background and tracked blobs
            [NSTimer scheduledTimerWithTimeInterval:2.0 block:^(void){
                blobTracker.reset();
                startTouchTracking();
                showFocusCalibration = 0;
                systemstate = SystemStates(systemstate+1);
//                sendMappingCorners();
            } repeats:NO];
        }
    } else
        msg = "Exposure calibrated";
    ofPushMatrix();
    ofSetHexColor(0xffff00);
    ofScale(2.0, 2.0);

    ofDrawBitmapString(msg, 120, 200);

    ofPopMatrix();
    
    showFocusCalibration--;
}

void Tracking::sendMappingCorners() {
    float xOff = calibration->objectPoints[0].x;
    float yOff = calibration->objectPoints[0].y;
    float xf = (calibration->objectPoints[calibration->objectPoints.size()-1].x-calibration->objectPoints[0].x)*projectionSize.width;
    float yf = (calibration->objectPoints[calibration->objectPoints.size()-1].y-calibration->objectPoints[0].y)*projectionSize.height;
        cv::Point2f topLeft = calibration->imagePoints[0];
        cv::Point2f topRight = calibration->imagePoints[5];
        cv::Point2f bottomLeft = calibration->imagePoints[calibration->imagePoints.size()-6];
        cv::Point2f bottomRight = calibration->imagePoints[calibration->imagePoints.size()-1];
        calibration->transformImgToObjPoint(topLeft);
        calibration->transformImgToObjPoint(topRight);
        calibration->transformImgToObjPoint(bottomLeft);
        calibration->transformImgToObjPoint(bottomRight);
        std::vector<CGPoint> mc;
        mc.push_back(CGPointMake((topLeft.x-xOff)*xf, (topLeft.y-yOff)*yf));
        mc.push_back(CGPointMake((topRight.x-xOff)*xf, (topRight.y-yOff)*yf));
        mc.push_back(CGPointMake((bottomLeft.x-xOff)*xf, (bottomLeft.y-yOff)*yf));
        mc.push_back(CGPointMake((bottomRight.x-xOff)*xf, (bottomRight.y-yOff)*yf));
    RUN_ON_UI_THREAD(^(void) {
        [viewController showMappingCorners:mc];
    });
}

//--------------------------------------------------------------
void Tracking::exit(){
        
}

//--------------------------------------------------------------
void Tracking::touchDown(ofTouchEventArgs & touch){

}

//--------------------------------------------------------------
void Tracking::touchMoved(ofTouchEventArgs & touch){
        
}
    
//--------------------------------------------------------------
void Tracking::touchUp(ofTouchEventArgs & touch){
    if (systemstate<FINGER_CALIBRATION) return;
    systemstate = FINGER_CALIBRATION;
    NSLog(@"CV Calibration");
    // start calibration
    showFocusCalibration = 80;
}
    
//--------------------------------------------------------------
void Tracking::touchDoubleTap(ofTouchEventArgs & touch){
    calibration->resetExtrinsics();
    ofiPhoneVideoGrabber * grabber = dynamic_cast<ofiPhoneVideoGrabber*> (&*vidGrabber.getGrabber());
    [grabber->grabber->grabber  lockExposureAndFocus:false];
    [viewController setCalibrationMode:true];
    systemstate = CAMERA_CALIBRATION_EXTRINSICS;
}
    
//--------------------------------------------------------------
void Tracking::touchCancelled(ofTouchEventArgs & touch){
        
}
    
//--------------------------------------------------------------
void Tracking::lostFocus(){
        
}
    
//--------------------------------------------------------------
void Tracking::gotFocus(){
        
}
    
//--------------------------------------------------------------
void Tracking::gotMemoryWarning(){
        
}
    
//--------------------------------------------------------------
void Tracking::deviceOrientationChanged(int newOrientation){
        
}

//void Tracking::vibrate() {
//    NSMutableDictionary* dict = [NSMutableDictionary dictionary];
//    NSMutableArray* arr = [NSMutableArray array ];
//    
//    [arr addObject:[NSNumber numberWithBool:NO]];  //stop for 1000ms
//    [arr addObject:[NSNumber numberWithInt:1000]];
//    
//    [arr addObject:[NSNumber numberWithBool:YES]]; //vibrate for 2000ms
//    [arr addObject:[NSNumber numberWithInt:400]];
//
//    [arr addObject:[NSNumber numberWithBool:NO]];  //stop for 1000ms
//    [arr addObject:[NSNumber numberWithInt:100]];
//
//    [arr addObject:[NSNumber numberWithBool:YES]]; //vibrate for 2000ms
//    [arr addObject:[NSNumber numberWithInt:400]];
//
//    //
////
////    
////    [arr addObject:[NSNumber numberWithBool:YES]];  //vibrate for 1000ms
////    [arr addObject:[NSNumber numberWithInt:1000]];
////    
//    [arr addObject:[NSNumber numberWithBool:NO]];    //stop for 500ms
//    [arr addObject:[NSNumber numberWithInt:500]];
//    
//    [dict setObject:arr forKey:@"VibePattern"];
//    [dict setObject:[NSNumber numberWithInt:255] forKey:@"Intensity"];
//    
//    
//    AudioServicesPlaySystemSoundWithVibration(kSystemSoundID_Vibrate,nil,dict);
//}
