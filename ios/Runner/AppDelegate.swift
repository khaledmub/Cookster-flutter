import UIKit
import Flutter
import GoogleMaps
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
 override func application(
   _ application: UIApplication,
   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
 ) -> Bool {
    GMSServices.provideAPIKey("AIzaSyCEvp7gFgGU7PjTLmjoI2Nly0Mlol5ZlaA")
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(
        .playback,
        mode: .moviePlayback,
        options: [.defaultToSpeaker]
      )
      try session.setActive(true)
    } catch {
      NSLog("AVAudioSession setup failed: \(error.localizedDescription)")
    }
       GeneratedPluginRegistrant.register(with: self)
       return super.application(application, didFinishLaunchingWithOptions: launchOptions)
 }

 override func applicationDidBecomeActive(_ application: UIApplication) {
   do {
     try AVAudioSession.sharedInstance().setActive(true)
   } catch {
     NSLog("AVAudioSession reactivate failed: \(error.localizedDescription)")
   }
   super.applicationDidBecomeActive(application)
 }
}

