#pragma once

#include "ofMain.h"
#include "ofxCv.h"
#include "ofxOpenCv.h"

class ChessCalibration : public ofBaseApp {
public:
	void setup(IplImage* input, string calibrationFileName);
	bool updateIntrinsics();
	bool updateExtrinsics();
	void drawIntrinsics();
    void drawExtrinsics();
    bool loadIntrinsics();
    bool loadExtrinsics();
    void setCam(IplImage* input);
    void transformImageExtrinsic(IplImage* input, IplImage* output);
    void transformObjToImgPoint(cv::Point2f &point);
    void transformImgToObjPoint(cv::Point2f &point);    
    void testReprojection();
    void createTransformImageExtrinsicMap(cv::Mat src);
    void resetExtrinsics();
    void createOffsetObjectPoints(float shrinkfactor=0.75);
	
    cv::Mat camMat;
    ofImage undistorted;
    cv::Mat previous;
    cv::Mat diff;
    cv::Mat mapping;
	float diffMean;
	
	float lastTime;
    string calibrationIntrinsicsFilePath;
    string calibrationExtrinsicsFilePath;
    
    vector<cv::Point3f> objectPoints;
	vector<cv::Point2f> imagePoints;
    cv::Mat rvec, tvec;
    
    bool found = false;
	cv::Size patternSize;
    float mappedWidth;
    float mappedHeight;
    float offsetX;
    float offsetY;
    float scaleFactor;
	
	ofxCv::Calibration calibration;
};
