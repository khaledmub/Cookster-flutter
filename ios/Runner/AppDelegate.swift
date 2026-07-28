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
    // AVAudioSession activation can block while another app holds the session.
    // Never do it on the launch critical path — the watchdog kills the app before
    // Flutter draws, which surfaces as a permanently white launch screen.
    DispatchQueue.global(qos: .userInitiated).async {
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
    }
       GeneratedPluginRegistrant.register(with: self)
       return super.application(application, didFinishLaunchingWithOptions: launchOptions)
 }
}

