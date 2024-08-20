import UIKit
import AVFoundation
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {

    private var methodChannel: FlutterMethodChannel?
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

        if let flutterViewController = window?.rootViewController as? FlutterViewController {
            methodChannel = FlutterMethodChannel(name: "pk.tritech.audiorecorder",
                                                 binaryMessenger: flutterViewController.binaryMessenger)

            methodChannel?.setMethodCallHandler { [weak self] (call, result) in
                switch call.method {
                case "startService":
                    self?.setupAudioSession()
                    self?.disableIdleTimer()
                    result("Screen won't lock")
                case "stopService":
                    self?.enableIdleTimer()
                    result("Screen can lock")
                default:
                    result(FlutterMethodNotImplemented)
                }
            }
        }

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }

    private func disableIdleTimer() {
        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = true
        }
    }

    private func enableIdleTimer() {
        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
}
