import SwiftUI
import CoreBluetooth
import Combine
import MediaPlayer
import AVFAudio
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        UIApplication.shared.beginReceivingRemoteControlEvents()
        return true
    }
}

class Observer: NSObject {
    let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
    }

    override func observeValue(
            forKeyPath keyPath: String?,
            of object: Any?,
            change: [NSKeyValueChangeKey: Any]?,
            context: UnsafeMutableRawPointer?
    ) {
        if keyPath == "outputVolume" {
            action()
        }
    }
}


@main
struct HeadsetDemoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    private let nowPlayingInfoCenter = MPNowPlayingInfoCenter.default()
    private let cmdCenter = MPRemoteCommandCenter.shared()
    private let audioEngine = AVAudioEngine()
    private let audioPlayerNode = AVAudioPlayerNode()
    @State private var observer: Observer? = nil

    @State private var isSetupped = false
    @State private var isRecording = false

    @State private var isAudioEngineRunning = false
    @State private var isAudioPlayerNodePlaying = false
    @State private var isOtherAudioPlaying = false
    @State private var inputNodeInputFormat: AVAudioFormat? = nil
    @State private var inputNodeOutputFormat: AVAudioFormat? = nil
    @State private var attachedNodes: [AVAudioNode] = []

    @State private var preferredInput: AVAudioSessionPortDescription? = nil
    @State private var availableInputs: [AVAudioSessionPortDescription] = []
    @State private var audioData: [AVAudioPCMBuffer] = []
    @State private var category: AVAudioSession.Category? = nil

    func setupObserver() {
        let audioSession: AVAudioSession = AVAudioSession.sharedInstance()

        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            isAudioEngineRunning = audioEngine.isRunning
            isAudioPlayerNodePlaying = audioPlayerNode.isPlaying
            availableInputs = audioSession.availableInputs ?? []
            category = audioSession.category
            isOtherAudioPlaying = audioSession.isOtherAudioPlaying
            preferredInput = audioSession.preferredInput
            inputNodeInputFormat = audioEngine.inputNode.inputFormat(forBus: 0)
            inputNodeOutputFormat = audioEngine.inputNode.outputFormat(forBus: 0)
            attachedNodes = audioEngine.attachedNodes.map { element -> AVAudioNode in element }
        }

        // observer = Observer { toggleRecording() }
        // AVAudioSession.sharedInstance().addObserver(observer!, forKeyPath: "outputVolume", options: .new, context: nil)
    }

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

    func toggleRecording() {
        if (isRecording) {
            stopRecording()
        } else {
            startRecording()
        }
    }

    func startRecording() {
        audioData = []
        print("Starting recording")
        isRecording = true
    }

    func stopRecording() {
        print("Stopping recording")
        isRecording = false
    }

    func setupAudioEngine() {
        audioEngine.attach(audioPlayerNode)
        audioEngine.connect(audioPlayerNode, to: audioEngine.outputNode, format: nil)

    }

    func installTap() {
        print("Installing tap")
        audioEngine.inputNode.installTap(onBus: 0, bufferSize: 8000, format: nil) { buffer, time in
            if (isRecording) {
                audioData.append(buffer)
            }
        }
    }

    func removeTap() {
        print("Removing tap")
        audioEngine.inputNode.removeTap(onBus: 0)
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
            Text("AudioSession").bold().padding().onAppear {
                setupObserver()
                setupCommandCenter()
            }

            VStack {
                Text("Other playing audio: \(isOtherAudioPlaying ? "yes" : "no")")
                Text("Category: \(category?.rawValue ?? "nil")")
                HStack {
                    Button("Set category") {
                        do {
                            try AVAudioSession.sharedInstance().setCategory(
                                    .playAndRecord,
                                    mode: .default,
                                    options: [.allowBluetooth]
                            )
                        } catch {
                            print("Error setting audio session category: \(error)")
                        }
                    }
                    Button("Activate") {
                        do {
                            try AVAudioSession.sharedInstance().setActive(true)
                        } catch {
                            print("Error enabling audio session: \(error)")
                        }
                    }
                    Button("Deactivate") {
                        do {
                            try AVAudioSession.sharedInstance().setActive(false)
                        } catch {
                            print("Error disabling audio session: \(error)")
                        }
                    }
                }
            }

            HStack {
                Text("Recording").bold()

                Text(isRecording ? "yes" : "no")

                if (!audioData.isEmpty && !isRecording) {
                    Button("Play") {
                        playRecording()
                    }
                }

                if (!isRecording) {
                    Button("Start") {
                        startRecording()
                    }
                } else {
                    Button("Stop") {
                        stopRecording()
                    }
                }
            }

            Text("AudioEngine").bold().padding()

            VStack {
                VStack {
                    Text("Audio engine running: \(isAudioEngineRunning ? "yes" : "no")")
                    Text("Audio player node playing: \(isAudioPlayerNodePlaying ? "yes" : "no")")
                    Text("Input node input format")
                    Text(inputNodeInputFormat?.debugDescription ?? "-")
                    Text("Input node output format")
                    Text(inputNodeOutputFormat?.debugDescription ?? "-")
                }

                VStack {
                    ForEach(attachedNodes, id: \.self) { (node: AVAudioNode) in
                        HStack {
                            Text(node.debugDescription).bold()
                        }
                                .frame(maxWidth: .infinity)
                                .padding(10)
                                .border(Color.black, width: 1)
                    }
                }
                        .padding([.horizontal], 20)

                HStack {
                    Text("Engine").bold()
                    Button("Setup") {
                        setupAudioEngine()
                    }
                    if (isAudioEngineRunning) {
                        Button("Stop") {
                            audioEngine.stop()
                        }
                        Button("Pause") {
                            audioEngine.pause()
                        }
                    } else {
                        Button("Start") {
                            do {
                                try audioEngine.start()
                            } catch {
                                print("Error starting audio engine: \(error)")
                            }
                        }
                    }
                    Button("Reset") {
                        audioEngine.reset()
                    }
                }

                HStack {
                    Text("Tap").bold()
                    Button("Install") {
                        installTap()
                    }
                    Button("Remove") {
                        removeTap()
                    }
                }
                if (isAudioEngineRunning) {
                    Button("Play sound") {
                        playSound()
                    }
                }
            }

            VStack {
                Text("Available Inputs:").bold()
                VStack {
                    ForEach(availableInputs, id: \.self) { (input: AVAudioSessionPortDescription) in
                        HStack {
                            Button(input.portName) {
                                do {
                                    try AVAudioSession.sharedInstance().setPreferredInput(input)
                                } catch {
                                    print("Error setting preferred input: \(error)")
                                }
                            }
                            Text(input.uid)
                        }
                                .frame(maxWidth: .infinity)
                                .padding(10)
                                .border(Color.black, width: 1)
                    }
                }.padding([.horizontal], 20)
            }
                .padding([.top], 20)
            HStack {
                Text("Preferred Input").bold()
                Text(preferredInput?.portName ?? "-")
            }
        }
    }
}
