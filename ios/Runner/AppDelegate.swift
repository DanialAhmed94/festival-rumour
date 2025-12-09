import Flutter
import UIKit
import Firebase
import GoogleMaps
@main
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        FirebaseApp.configure()
        if let apiKey = ProcessInfo.processInfo.environment["GOOGLE_MAPS_API_KEY"] {
            GMSServices.provideAPIKey(apiKey)
        } else {
            print("Missing Google Maps API Key")
        }
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
