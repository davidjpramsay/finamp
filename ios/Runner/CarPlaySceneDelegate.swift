//
//  CarPlaySceneDelegate.swift
//  Runner
//
//  CarPlay scene delegate for Finamp - reproduces flutter_carplay plugin delegate logic
//

import UIKit
import CarPlay
import Flutter

// Need to replicate the plugin's channel constants
private let FCPChannelId = "flutter_carplay"
private func makeFCPChannelId(event: String) -> String {
    return "\(FCPChannelId)/\(event)"
}

@available(iOS 14.0, *)
@objc(CarPlaySceneDelegate)
class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate, CPInterfaceControllerDelegate, CPNowPlayingTemplateObserver {

    private static var interfaceController: CPInterfaceController?
    private var finampUIChannel: FlutterMethodChannel?
    private var shuffleButton: CPNowPlayingShuffleButton?
    private var repeatButton: CPNowPlayingRepeatButton?

    override init() {
        super.init()
        NSLog("[FINAMP-CarPlay] CarPlaySceneDelegate initialized")
    }

    @objc(templateApplicationScene:didConnectInterfaceController:)
    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                   didConnect interfaceController: CPInterfaceController) {
        NSLog("[FINAMP-CarPlay] didConnect interfaceController")

        CarPlaySceneDelegate.interfaceController = interfaceController
        interfaceController.delegate = self

        // Send connection event to Flutter using the plugin's event channel
        _ = FlutterEventChannel(
            name: makeFCPChannelId(event: "onCarplayConnectionChange"),
            binaryMessenger: flutterEngine.binaryMessenger
        )

        // Also try method channel approach
        let methodChannel = FlutterMethodChannel(
            name: makeFCPChannelId(event: ""),
            binaryMessenger: flutterEngine.binaryMessenger
        )

        configureFinampNowPlaying()

        // Notify Flutter that CarPlay connected
        methodChannel.invokeMethod("onCarplayConnectionChange", arguments: ["status": "connected"])

        NSLog("[FINAMP-CarPlay] CarPlay connected successfully - notified Flutter")
    }

    @objc(templateApplicationScene:didDisconnectInterfaceController:)
    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                   didDisconnectInterfaceController interfaceController: CPInterfaceController) {
        NSLog("[FINAMP-CarPlay] didDisconnectInterfaceController")

        // Notify Flutter of disconnection
        let methodChannel = FlutterMethodChannel(
            name: makeFCPChannelId(event: ""),
            binaryMessenger: flutterEngine.binaryMessenger
        )
        methodChannel.invokeMethod("onCarplayConnectionChange", arguments: ["status": "disconnected"])

        interfaceController.delegate = nil
        CarPlaySceneDelegate.interfaceController = nil
        CPNowPlayingTemplate.shared.remove(self)
        finampUIChannel?.setMethodCallHandler(nil)
        finampUIChannel = nil

        NSLog("[FINAMP-CarPlay] CarPlay disconnected")
    }

    // Scene lifecycle events
    func sceneDidBecomeActive(_ scene: UIScene) {
        NSLog("[FINAMP-CarPlay] sceneDidBecomeActive")
        let methodChannel = FlutterMethodChannel(
            name: makeFCPChannelId(event: ""),
            binaryMessenger: flutterEngine.binaryMessenger
        )
        methodChannel.invokeMethod("onCarplayConnectionChange", arguments: ["status": "connected"])
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        NSLog("[FINAMP-CarPlay] sceneDidEnterBackground")
        let methodChannel = FlutterMethodChannel(
            name: makeFCPChannelId(event: ""),
            binaryMessenger: flutterEngine.binaryMessenger
        )
        methodChannel.invokeMethod("onCarplayConnectionChange", arguments: ["status": "background"])
    }

    // CPInterfaceControllerDelegate method
    func templateDidDisappear(_ template: CPTemplate, animated: Bool) {
        NSLog("[FINAMP-CarPlay] templateDidDisappear")
    }

    // MARK: - Finamp Now Playing

    private func configureFinampNowPlaying() {
        let channel = FlutterMethodChannel(
            name: "finamp/carplay_ui",
            binaryMessenger: flutterEngine.binaryMessenger
        )
        finampUIChannel = channel

        let nowPlayingTemplate = CPNowPlayingTemplate.shared
        nowPlayingTemplate.remove(self)
        nowPlayingTemplate.add(self)
        nowPlayingTemplate.isUpNextButtonEnabled = true

        let shuffle = CPNowPlayingShuffleButton { [weak self] button in
            self?.finampUIChannel?.invokeMethod("toggleShuffle", arguments: nil) { response in
                if let selected = response as? Bool {
                    button.isSelected = selected
                }
            }
        }
        let repeatMode = CPNowPlayingRepeatButton { [weak self] button in
            self?.finampUIChannel?.invokeMethod("toggleRepeat", arguments: nil) { response in
                if let selected = response as? Bool {
                    button.isSelected = selected
                }
            }
        }
        shuffleButton = shuffle
        repeatButton = repeatMode
        nowPlayingTemplate.updateNowPlayingButtons([shuffle, repeatMode])

        channel.setMethodCallHandler { [weak self] call, result in
            switch call.method {
            case "syncPlaybackModes":
                guard let arguments = call.arguments as? [String: Any] else {
                    result(FlutterError(code: "invalid_arguments", message: "Missing playback mode state", details: nil))
                    return
                }
                self?.shuffleButton?.isSelected = arguments["shuffle"] as? Bool ?? false
                self?.repeatButton?.isSelected = arguments["repeat"] as? Bool ?? false
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    func nowPlayingTemplateUpNextButtonTapped(_ nowPlayingTemplate: CPNowPlayingTemplate) {
        finampUIChannel?.invokeMethod("showUpNext", arguments: nil)
    }
}
