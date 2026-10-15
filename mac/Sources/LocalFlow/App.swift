import SwiftUI
import WhisperKit

@main
struct LocalFlowApp: App {
    @StateObject private var dictation = Dictation()

    var body: some Scene {
        MenuBarExtra {
            Text(dictation.status)
            Divider()
            SettingsButton()
            Button("Quit") { NSApp.terminate(nil) }.keyboardShortcut("q")
        } label: {
            Image(systemName: dictation.icon)
        }

        // A plain Window, not Settings: SettingsLink doesn't reliably open or focus in a menu bar-only app.
        Window("LocalFlow Settings", id: "settings") {
            SettingsView().environmentObject(dictation)
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)
    }
}

struct SettingsButton: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Settings…") {
            openWindow(id: "settings")
            NSApp.activate(ignoringOtherApps: true)
        }
        .keyboardShortcut(",")
    }
}

struct SettingsView: View {
    @EnvironmentObject var dictation: Dictation
    @AppStorage("mic") private var mic = ""
    @AppStorage("hotkey") private var hotkey = Hotkey.rightControl.rawValue
    @AppStorage("language") private var language = "en"
    @AppStorage("model") private var model = Dictation.defaultModel
    @State private var mics: [AudioDevice] = []

    var body: some View {
        Form {
            Picker("Microphone", selection: $mic) {
                Text("System default").tag("")
                ForEach(mics, id: \.name) { Text($0.name).tag($0.name) }
            }
            Picker("Hold to talk", selection: $hotkey) {
                ForEach(Hotkey.allCases, id: \.rawValue) { Text($0.label).tag($0.rawValue) }
            }
            TextField("Language", text: $language, prompt: Text("empty = auto-detect"))
            TextField("Model", text: $model)
                .onSubmit { dictation.loadModel() }
            Text("Any model from huggingface.co/argmaxinc/whisperkit-coreml. Press Return to load it.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .onAppear { mics = AudioProcessor.getAudioDevices() }
    }
}
