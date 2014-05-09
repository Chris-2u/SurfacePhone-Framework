#pragma once


#include "ofMain.h"
#include "ofxiPhone.h"
#include "ofxiPhoneExtras.h"
#include "ofxiPhoneViewController.h"
#include "ofxBlob.h"
#include "ofxBlobTracker.h"
#include "ofxCv.h"
#include "ChessCalibration.h"
#include "ofxOpticalFlowLK.h"

//ON IPHONE NOTE INCLUDE THIS BEFORE ANYTHING ELSE
#include "ofxOpenCv.h"

//warning video player doesn't currently work - use live video only
#define _USE_LIVE_VIDEO
static const bool HUEbased = false;

class Tracking : public ofxiPhoneApp{
	  
	public:

    void setup();
    void update();
    void draw();
    void exit();
    void initCamera();
    void startTouchTracking();
    void timeoutTouchRecognition();

    void touchDown(ofTouchEventArgs & touch);
    void touchMoved(ofTouchEventArgs & touch);
    void touchUp(ofTouchEventArgs & touch);
    void touchDoubleTap(ofTouchEventArgs & touch);
    void touchCancelled(ofTouchEventArgs & touch);

    void lostFocus();
    void gotFocus();
    void gotMemoryWarning();
    void deviceOrientationChanged(int newOrientation);
    void cameraFingerCalibration();
    void fingerTestDriver();
    void mappingTestDriver();
    void fireFingerEvent(float x, float y, int touch = 0);
    void sendMappingCorners();
    
    static void accelChanged(ofPoint &data);
   
    #ifdef _USE_LIVE_VIDEO
        ofVideoGrabber vidGrabber;
    #endif
    ofVideoPlayer vidPlayer;

    ofTexture tex;

    ofxCvColorImage	colorImg;
    ofxCvColorImage previousImg;

    ofxCvGrayscaleImage grayImage;
    ofxCvGrayscaleImage grayBg;
    ofxCvGrayscaleImage grayDiff;
    
    float capW;
    float capH;

    bool bLearnBakground;
    
//########
    ofxiPhoneViewController* viewController;
    float BlobX;
    float BlobY;
    void BlobLocalization();
    BOOL userInteractionRecognized;
    float AvAc;

    int counter;
    
    void blobAdded(ofxBlob &_blob);
    void blobMoved(ofxBlob &_blob);
    void blobDeleted(ofxBlob &_blob);
    void processGestureData();
    
    ofxBlobTracker          blobTracker;
    
    static void emptyAcc();
    static float avgAcc();
    static float maxAcc();
    static float minAcc();
};
//
//FOUNDATION_EXTERN void AudioServicesPlaySystemSoundWithVibration(SystemSoundID inSystemSoundID,id arg,NSDictionary* vibratePattern);

