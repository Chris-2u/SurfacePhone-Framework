#include "ChessCalibration.h"


using namespace ofxCv;
using namespace cv;

const float diffThreshold = 2.5; // maximum amount of movement
const float timeThreshold = 4; // minimum time between snapshots
const int startCleaning = 6; // start cleaning outliers after this many samples
const int numBoards = 8;
int cNumBoards = 0;

void ChessCalibration::setup(IplImage* input, string calibrationPath) {
    
    this->calibrationIntrinsicsFilePath = calibrationPath + "/calibrationIntrinsics.yml";
    this->calibrationExtrinsicsFilePath = calibrationPath + "/calibrationExtrinsics.yml";
	ofSetVerticalSync(true);
    
	FileStorage settings(ofToDataPath("settings.yml"), FileStorage::READ);
	if(settings.isOpened()) {
		int xCount = settings["xCount"], yCount = settings["yCount"];
		calibration.setPatternSize(xCount, yCount);
		float squareSize = settings["squareSize"];
		calibration.setSquareSize(squareSize);
		CalibrationPattern patternType;
		switch(settings["patternType"]) {
			case 0: patternType = CHESSBOARD; break;
			case 1: patternType = CIRCLES_GRID; break;
			case 2: patternType = ASYMMETRIC_CIRCLES_GRID; break;
		}
		calibration.setPatternType(patternType);
	}
    camMat = Mat(input);
	ofImage temp;
    toOf(Mat(input,true), temp);
    imitate(undistorted, temp);
	previous = Mat(input, true);
	diff = Mat(input, true);
    mapping.create( camMat.size(), CV_32FC2 );
	lastTime = 0;
}
void ChessCalibration::setCam(IplImage* input) {
    camMat = Mat(input);
}
bool ChessCalibration::loadIntrinsics() {
	if (!calibration.load(calibrationIntrinsicsFilePath))
        return false;
    // prepare for extrinsics
    patternSize = calibration.getPatternSize();
    createOffsetObjectPoints();
    return true;
}

void ChessCalibration::createOffsetObjectPoints(float shrinkfactor) {
    // Create object points with area around
    objectPoints.clear();
    float squareSize = calibration.getSquareSize()*shrinkfactor;
    scaleFactor = 1.0/shrinkfactor;
    mappedWidth = patternSize.width*squareSize;
    mappedHeight = patternSize.height*squareSize;
    offsetX = (patternSize.width*calibration.getSquareSize()-mappedWidth)/2.0;
    offsetY = (patternSize.height*calibration.getSquareSize()-mappedHeight)/2.0;
    for(int i = 0; i < patternSize.height; i++)
        for(int j = 0; j < patternSize.width; j++)
            objectPoints.push_back(Point3f(float(j * squareSize)+offsetX, float(i * squareSize)+offsetY, 0));
}

bool ChessCalibration::loadExtrinsics() {
	FileStorage fs(calibrationExtrinsicsFilePath, FileStorage::READ);
    if (!fs.isOpened())
        return false;
	imagePoints.clear();
    found = true;
	fs["rvec"] >> rvec;
  	fs["tvec"] >> tvec;
    FileNode features = fs["features"];
    for(FileNodeIterator it = features.begin(); it != features.end(); it++) {
        vector<Point2f> cur;
        (*it) >> cur;
        imagePoints.push_back(cur[0]);
    }
    fs["mapping"] >> mapping;
    cout << "Extrinsics loaded from file" << endl;
//    createTransformImageExtrinsicMap(camMat);
//    fs.release();
//    FileStorage fs2(calibrationExtrinsicsFilePath, FileStorage::APPEND);
//    fs2 << "mapping" << mapping;
    return true;
}
void ChessCalibration::resetExtrinsics() {
    imagePoints.clear();
    found = false;
    rvec = Mat();
    tvec = Mat();
}

bool ChessCalibration::updateIntrinsics() {
//    Mat camMat(input);
    
    absdiff(previous, camMat, diff);
    camMat.copyTo(previous);
    
    diffMean = mean(Mat(mean(diff)))[0];
//    cout << "Diff Mean " << diffMean << endl;
    
    float curTime = ofGetElapsedTimef();
    if(curTime - lastTime > timeThreshold && diffMean < diffThreshold) {
        Mat camMatCopy(camMat);
        if(calibration.add(camMatCopy)) {
            cNumBoards++;
            AudioServicesPlaySystemSound (1003);
            cout << "re-calibrating" << endl;
            calibration.calibrate();
            if(calibration.size() > startCleaning) {
                calibration.clean();
            }
            if(cNumBoards == numBoards) {
                calibration.save(calibrationIntrinsicsFilePath);
                createOffsetObjectPoints();
                return true;
            }
            lastTime = curTime;
        }
    }
    if(calibration.size() > 0) {
        calibration.undistort(camMat, toCv(undistorted));
        undistorted.update();
    }
    
    return false;
}

bool ChessCalibration::updateExtrinsics() {
    absdiff(previous, camMat, diff);
    camMat.copyTo(previous);
    
    diffMean = mean(Mat(mean(diff)))[0];
    //    cout << "Diff Mean " << diffMean << endl;
    
    if(diffMean < diffThreshold) {
        Mat camMatCopy(camMat);
        found = calibration.findBoard(camMatCopy, imagePoints, false);
        
        if(found) {
            AudioServicesPlaySystemSound (1005);
            Mat cameraMatrix = calibration.getDistortedIntrinsics().getCameraMatrix();
            solvePnPRansac(Mat(objectPoints), Mat(imagePoints), cameraMatrix, calibration.getDistCoeffs(), rvec, tvec, false);
            FileStorage fs(calibrationExtrinsicsFilePath, FileStorage::WRITE);
            fs << "rvec" << rvec;
            fs << "tvec" << tvec;
            fs << "features" << "[";
            for(int i = 0; i < (int)imagePoints.size(); i++) {
                fs << imagePoints[i];
            }
            fs << "]";
            createTransformImageExtrinsicMap(camMat);
            fs << "mapping" << mapping;
        } else
            AudioServicesPlaySystemSound (1100);
    }
    return found;
}

void ChessCalibration::drawIntrinsics() {
	ofSetColor(255);
    undistorted.draw(480,0, 480, 360);
    
    return;
	stringstream intrinsics;
	intrinsics << "fov: " << toOf(calibration.getDistortedIntrinsics().getFov()) << " distCoeffs: " << calibration.getDistCoeffs();
	drawHighlightString(intrinsics.str(), 10, 370, yellowPrint, ofColor(0));
	drawHighlightString("movement: " + ofToString(diffMean), 10, 390, cyanPrint);
	drawHighlightString("reproj error: " + ofToString(calibration.getReprojectionError()) + " from " + ofToString(calibration.size()), 10, 410, magentaPrint);
//	for(int i = 0; i < calibration.size(); i++) {
//		drawHighlightString(ofToString(i) + ": " + ofToString(calibration.getReprojectionError(i)), 10, 80 + 16 * i, magentaPrint);
//	}
}

void ChessCalibration::drawExtrinsics() {
    if(found) {
        cv::drawChessboardCorners(camMat, patternSize, imagePoints, found);
	}
}

void ChessCalibration::transformImageExtrinsic(IplImage* input, IplImage* output) {
    Mat warped (output), image(input);
    // compute map using point function below
    remap(image, warped, mapping, Mat(), INTER_LINEAR);
    warped.release();
    image.release();
}

void ChessCalibration::createTransformImageExtrinsicMap(Mat src) {
    cout << "Create map for extrinsic undistortion" << endl;
    for( int j = 0; j < src.rows; j++ )
    {
        for( int i = 0; i < src.cols; i++ )
        {
            Point2f p (i,j);
            transformObjToImgPoint(p);
            mapping.at<Point2f>(j,i) = p;
        }
    }
}

void ChessCalibration::transformObjToImgPoint(Point2f &point) {
    vector<Point3f> inpoint(1);
    inpoint[0] = Point3f(point.x, point.y, 0);
    vector<Point2f> outpoint(1);
    projectPoints(inpoint, rvec, tvec, calibration.getDistortedIntrinsics().getCameraMatrix(), calibration.getDistCoeffs(), outpoint);
    point.x = outpoint[0].x;
    point.y = outpoint[0].y;
}

void ChessCalibration::transformImgToObjPoint(Point2f &point) {
    cv::Mat uvPoint = cv::Mat::ones(3,1,cv::DataType<double>::type); //u,v,1
    uvPoint.at<double>(0,0) = point.x; //got this point using mouse callback
    uvPoint.at<double>(1,0) = point.y;
    cv::Mat tempMat, tempMat2, rotationMatrix;
    Rodrigues(rvec, rotationMatrix);
    double s;
    tempMat = rotationMatrix.inv() * calibration.getDistortedIntrinsics().getCameraMatrix().inv() * uvPoint;
    tempMat2 = rotationMatrix.inv() * tvec;
    s = tempMat2.at<double>(2,0); 
    s /= tempMat.at<double>(2,0);
    uvPoint = rotationMatrix.inv() * (s * calibration.getDistortedIntrinsics().getCameraMatrix().inv() * uvPoint - tvec);
    point.x = uvPoint.at<double>(0,0);
    point.y = uvPoint.at<double>(1,0);
}

void ChessCalibration::testReprojection() {
    float errorSum = 0;
    for(int i = 0; i < (int)imagePoints.size(); i++) {
        Point2f point;
        point.x = imagePoints[i].x;
        point.y = imagePoints[i].y;
        transformImgToObjPoint(point);
        float error = sqrt(pow(point.x-objectPoints[i].x,2) + pow(point.y-objectPoints[i].y,2));
        cout << "Reproject from " << imagePoints[i] << " imagePoint to " << objectPoints[i] << " objectPoint is " << point << ", error " << error << endl;
        errorSum += error;
    }
    cout << "Total reprojection error: " << (errorSum/imagePoints.size()) << endl;
}

