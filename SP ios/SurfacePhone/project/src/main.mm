// The "heart" of the framework is at "Tracking.mm"

#include "Tracking.h"
#include "ofMain.h"

int main(){
	ofSetupOpenGL(1024,768, OF_FULLSCREEN);			// <-------- setup the GL context
	ofRunApp(new Tracking);
   
}
