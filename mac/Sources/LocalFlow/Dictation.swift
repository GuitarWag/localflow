import AppKit
import AVFoundation
import WhisperKit

enum Hotkey: String, CaseIterable {
    case rightControl, rightOption, rightCommand, fn

    var label: String {
        switch self {
        case .rightControl: "Right Control"
        case .rightOption: "Right Option"
        case .rightCommand: "Right Command"
        case .fn: "Fn"
        }
    }

    var keyCode: UInt16 {
        switch self {
        case .rightControl: 62
        case .rightOption: 61
        case .rightCommand: 54
        case .fn: 63
        }
    }

    var flag: NSEvent.ModifierFlags {
        switch self {
        case .rightControl: .control
        case .rightOption: .option
        case .rightCommand: .command
        case .fn: .function
        }
    }
}

@MainActor
final class Dictation: ObservableObject {
    static let defaultModel = "openai_whisper-large-v3-v20240930_turbo"
    static let rate = 16000
    static let minSeconds = 0.3

    @Published var status = "Starting…"
    @Published var icon = "mic"

    private let defaults = UserDefaults.standard
    private let audio = AudioProcessor()
    private var whisper: WhisperKit?
    private var recording = false
    private var queue: Task<Void, Never>?  // serializes transcriptions, like the Python job queue
    private var monitors: [Any] = []

    init() {
        AVCaptureDevice.requestAccess(for: .audio) { _ in }
        // Prompts for Accessibility, needed for the global key monitor and for sending Cmd+V.
        AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary)
        let handler: (NSEvent) -> Void = { [weak self] event in
            MainActor.assumeIsolated { self?.flagsChanged(event) }
        }
        monitors.append(NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: handler) as Any)
        monitors.append(NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { handler($0); return $0 } as Any)
        loadModel()
    }

    func loadModel() {
        let model = defaults.string(forKey: "model") ?? Self.defaultModel
        whisper = nil
        set("Loading \(model)… (first run downloads it)", icon: "arrow.down.circle")
        queue = Task { [queue] in
            await queue?.value
            do {
                let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent("LocalFlow")
                let kit = try await WhisperKit(WhisperKitConfig(model: model, downloadBase: base, verbose: false))
                _ = try await kit.transcribe(audioArray: [Float](repeating: 0, count: Self.rate))  // warm up
                whisper = kit
                if AXIsProcessTrusted() {
                    set("Ready. Hold \(hotkey.label) to dictate.", icon: "mic")
                } else {
                    set("Needs Accessibility: System Settings > Privacy & Security > Accessibility, then relaunch.",
                        icon: "exclamationmark.triangle")
                }
            } catch {
                set("Model failed: \(error.localizedDescription)", icon: "exclamationmark.triangle")
            }
        }
    }

    private var hotkey: Hotkey {
        Hotkey(rawValue: defaults.string(forKey: "hotkey") ?? "") ?? .rightControl
    }

    private func flagsChanged(_ event: NSEvent) {
        let key = hotkey
        guard event.keyCode == key.keyCode, whisper != nil else { return }
        if event.modifierFlags.contains(key.flag) { start() } else { stop() }
    }

    private func start() {
        guard !recording else { return }
        let name = defaults.string(forKey: "mic") ?? ""
        let device = AudioProcessor.getAudioDevices().first { $0.name == name }?.id  // nil = system default
        do {
            try audio.startRecordingLive(inputDeviceID: device, callback: nil)
        } catch {
            set("Mic failed: \(error.localizedDescription)", icon: "exclamationmark.triangle")
            return
        }
        recording = true
        NSSound(named: "Tink")?.play()
        set("Listening…", icon: "mic.fill")
    }

    private func stop() {
        guard recording else { return }
        recording = false
        audio.stopRecording()
        NSSound(named: "Tink")?.play()
        let samples = Array(audio.audioSamples)
        guard Double(samples.count) >= Double(Self.rate) * Self.minSeconds, let kit = whisper else {
            set("Ready. Hold \(hotkey.label) to dictate.", icon: "mic")
            return
        }
        let lang = (defaults.string(forKey: "language") ?? "en").nilIfEmpty
        let options = DecodingOptions(language: lang, detectLanguage: lang == nil,
                                      skipSpecialTokens: true, withoutTimestamps: true)
        set("Transcribing…", icon: "ellipsis.circle")
        queue = Task { [queue] in
            await queue?.value
            let t0 = Date()
            let text = ((try? await kit.transcribe(audioArray: samples, decodeOptions: options)) ?? [])
                .map(\.text).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            print(String(format: "[%.1fs] %@", Date().timeIntervalSince(t0), text))
            if !text.isEmpty { await paste(text + " ") }
            if !recording { set("Ready. Hold \(hotkey.label) to dictate.", icon: "mic") }
        }
    }

    private func paste(_ text: String) async {
        let board = NSPasteboard.general
        let old = board.string(forType: .string)
        board.clearContents()
        board.setString(text, forType: .string)
        let src = CGEventSource(stateID: .hidSystemState)
        for down in [true, false] {
            let event = CGEvent(keyboardEventSource: src, virtualKey: 9, keyDown: down)  // 9 = V
            event?.flags = .maskCommand
            event?.post(tap: .cghidEventTap)
        }
        try? await Task.sleep(for: .milliseconds(300))  // let the target app read the clipboard before restoring it
        board.clearContents()
        if let old { board.setString(old, forType: .string) }
    }

    private func set(_ status: String, icon: String) {
        self.status = status
        self.icon = icon
    }
}

extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
