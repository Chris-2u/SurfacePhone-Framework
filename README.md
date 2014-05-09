SurfacePhone Framework by Christian Winkler (cwinkler.eu@gmail.com)
As used in http://dx.doi.org/10.1145/2556288.2557075 (requires ACM access) or http://uulm.de?SurfacePhone
  
The system supports touch and gesture recognition on the projected surface
as well as a study and logging application to test for these capabilities.

The interesting files you might want to alter are:
- Tracking                   for general application flow, vibration and camera tracking
- OfxiPhoneViewController     for all view related things regarding iPhone or projected display
- Gestures.json               for supported gestures (see 1$ gesture recognizer)

For steps 1 and 2 camera parameter calibration files will be placed in the app folder upon success.
For the first step you have to print chessboard_6x4 720.png, but you can alter settings.yml to play with alternatives.
If calibration does not work for you, you find good calibrations in the root folder that you can copy to the app using iTunes.