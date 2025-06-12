import UIKit
import Flutter
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
 override func application(
   _ application: UIApplication,
   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
 ) -> Bool {
    GMSServices.provideAPIKey("AIzaSyCEvp7gFgGU7PjTLmjoI2Nly0Mlol5ZlaA")
       GeneratedPluginRegistrant.register(with: self)
       return super.application(application, didFinishLaunchingWithOptions: launchOptions)
 }
}



