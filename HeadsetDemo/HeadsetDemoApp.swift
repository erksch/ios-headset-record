import SwiftUI
import CoreBluetooth
import Combine
import MediaPlayer
import AVFAudio
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        app.beginReceivingRemoteControlEvents()
        return true
    }
}

@main
struct HeadsetDemoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    private let cmdCenter = MPRemoteCommandCenter.shared()
    private let audioEngine = AVAudioEngine()
    private let audioPlayerNode = AVAudioPlayerNode()
    
    @State private var isSetupped = false
    @State private var isRecording = false

    @State private var isAudioEngineRunning = false
    @State private var isAudioPlayerNodePlaying = false

    @State private var availableInputs: [AVAudioSessionPortDescription] = []
    @State private var audioData: [AVAudioPCMBuffer] = []

    func playSound() {
        do {
            let soundFile = try getSoundFile(name: "sound")
            audioPlayerNode.scheduleFile(soundFile, at: nil, completionCallbackType: .dataPlayedBack) { _ in
                audioPlayerNode.pause()
            }
            audioPlayerNode.play()
        } catch {
            print("Unable to play sound: \(error)")
        }
    }
    
    func playRecording() {
        do {
            try audioData.forEach { buffer in
                let convertedAudioData = try convertBufferToFormat(buffer: buffer, outputFormat: audioPlayerNode.outputFormat(forBus: 0))
                audioPlayerNode.scheduleBuffer(convertedAudioData)
            }
            audioPlayerNode.play()
        } catch {
            print("Unable to play recording: \(error)")
        }
    }

    func startRecording() {
        audioData = []
        isRecording = true
    }

    func stopRecording() {
        isRecording = false
    }

    func setup() {
        let audioSession: AVAudioSession = AVAudioSession.sharedInstance()

        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            isAudioEngineRunning = audioEngine.isRunning
            isAudioPlayerNodePlaying = audioPlayerNode.isPlaying
            availableInputs = audioSession.availableInputs ?? []
        }

        do {
            try audioSession.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.allowBluetooth]
            )
            try audioSession.setActive(true)
        } catch {
            print("Error setting audio session category: \(error)")
        }

        audioEngine.attach(audioPlayerNode)
        audioEngine.connect(audioPlayerNode, to: audioEngine.outputNode, format: nil)
        audioEngine.inputNode.installTap(onBus: 0, bufferSize: 8000, format: nil) { buffer, time in
            if (isRecording) {
                audioData.append(buffer)
            }
        }
        
        /**
         * We start the `audioEngine` immediately to be able to start recording from the background.
         * Otherwise, if we would start the `audioEngine` on headset button press from the background, the app would crash.
         * See: https://stackoverflow.com/a/61347295/8170620
         */
        do {
            try audioEngine.start()
        } catch {
            print("Error starting audio engine: \(error)")
        }

        setupCommandCenter()
        isSetupped = true
    }

    func setupCommandCenter() {
        /**
         * Is only called when `audioEngine` is not running.
         * So if we start the `audioEngine` immediately, we do not expect this be called.
         */
        cmdCenter.playCommand.addTarget { event in
            print("registered play")
            return .success
        }
        cmdCenter.playCommand.isEnabled = true

        cmdCenter.pauseCommand.addTarget { event in
            print("registered pause")
            return .success
        }
        cmdCenter.pauseCommand.isEnabled = true
    }

    var body: some Scene {
        WindowGroup {
            if (isSetupped) {
                Button("Play sound") {
                    playSound()
                }.padding(20)
                
                if (!audioData.isEmpty && !isRecording) {
                    Button("Play recording") {
                        playRecording()
                    }.padding(20)
                }
                
                if (!isRecording) {
                    Button("Start recording") {
                        startRecording()
                    }.padding(20)
                } else {
                    Button("Stop recording") {
                        stopRecording()
                    }.padding(20)
                }
                
                Text("Audio engine running: \(isAudioEngineRunning ? "yes" : "no")")
                Text("Audio player node playing: \(isAudioPlayerNodePlaying ? "yes" : "no")")
                
                Text("Available Inputs:").bold().padding()
                
                VStack {
                    ForEach(availableInputs, id: \.self) { (input: AVAudioSessionPortDescription) in
                        HStack {
                            Text(input.portName).bold()
                            Text(input.uid)
                        }
                            .frame(maxWidth: .infinity)
                            .padding(10)
                            .border(Color.black, width: 1)
                    }
                }.padding([.horizontal], 20)
            } else {
                Button("Setup") {
                    setup()
                }.padding(20)
            }
        }
    }
}
