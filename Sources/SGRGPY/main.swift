import Foundation
import AppKit
import SwiftUI

struct Profile: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var resolution: Int
    var bitrate: Int
    var fps: Int
    var audioEnabled: Bool
    var fullscreen: Bool
    var mirrorMode: Bool
    var showTouches: Bool
    var keepAwake: Bool
}

struct AppSettings: Codable {
    var selectedAppearance: String
    var pullDestination: String
    var deviceSerial: String
    var resolution: Int
    var bitrate: Int
    var fps: Int
    var audioEnabled: Bool
    var fullscreen: Bool
    var mirrorMode: Bool
    var showTouches: Bool
    var keepAwake: Bool
    var recordEnabled: Bool
    var profiles: [Profile]
    var selectedProfileID: UUID?
}

final class SettingsStore: ObservableObject {
    @Published var selectedAppearance: String = "Dark" { didSet { persist() } }
    @Published var pullDestination: String = NSHomeDirectory() + "/Downloads" { didSet { persist() } }
    @Published var deviceSerial: String = "" { didSet { persist() } }
    @Published var resolution: Int = 1080 { didSet { persist() } }
    @Published var bitrate: Int = 8_000_000 { didSet { persist() } }
    @Published var fps: Int = 60 { didSet { persist() } }
    @Published var audioEnabled: Bool = true { didSet { persist() } }
    @Published var fullscreen: Bool = false { didSet { persist() } }
    @Published var mirrorMode: Bool = true { didSet { persist() } }
    @Published var showTouches: Bool = false { didSet { persist() } }
    @Published var keepAwake: Bool = true { didSet { persist() } }
    @Published var recordEnabled: Bool = false { didSet { persist() } }
    @Published var profiles: [Profile] = [] { didSet { persist() } }
    @Published var selectedProfileID: UUID? = nil { didSet { persist() } }

    private let storageURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSHomeDirectory() + "/Library/Application Support")
        let dirURL = appSupport.appendingPathComponent("SGRGPY", isDirectory: true)
        try? FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
        storageURL = dirURL.appendingPathComponent("settings.json")
        load()
    }

    func load() {
        if let data = try? Data(contentsOf: storageURL),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            selectedAppearance = decoded.selectedAppearance
            pullDestination = decoded.pullDestination
            deviceSerial = decoded.deviceSerial
            resolution = decoded.resolution
            bitrate = decoded.bitrate
            fps = decoded.fps
            audioEnabled = decoded.audioEnabled
            fullscreen = decoded.fullscreen
            mirrorMode = decoded.mirrorMode
            showTouches = decoded.showTouches
            keepAwake = decoded.keepAwake
            recordEnabled = decoded.recordEnabled
            profiles = decoded.profiles.isEmpty ? Self.defaultProfiles() : decoded.profiles
            selectedProfileID = decoded.selectedProfileID
            return
        }

        profiles = Self.defaultProfiles()
        selectedProfileID = profiles.first?.id
    }

    func persist() {
        let payload = AppSettings(
            selectedAppearance: selectedAppearance,
            pullDestination: pullDestination,
            deviceSerial: deviceSerial,
            resolution: resolution,
            bitrate: bitrate,
            fps: fps,
            audioEnabled: audioEnabled,
            fullscreen: fullscreen,
            mirrorMode: mirrorMode,
            showTouches: showTouches,
            keepAwake: keepAwake,
            recordEnabled: recordEnabled,
            profiles: profiles,
            selectedProfileID: selectedProfileID
        )

        if let data = try? JSONEncoder().encode(payload) {
            try? data.write(to: storageURL)
        }
    }

    func applyProfile(_ profile: Profile) {
        resolution = profile.resolution
        bitrate = profile.bitrate
        fps = profile.fps
        audioEnabled = profile.audioEnabled
        fullscreen = profile.fullscreen
        mirrorMode = profile.mirrorMode
        showTouches = profile.showTouches
        keepAwake = profile.keepAwake
        selectedProfileID = profile.id
    }

    func saveCurrentAsProfile() {
        let profile = Profile(
            name: "Preset \(profiles.count + 1)",
            resolution: resolution,
            bitrate: bitrate,
            fps: fps,
            audioEnabled: audioEnabled,
            fullscreen: fullscreen,
            mirrorMode: mirrorMode,
            showTouches: showTouches,
            keepAwake: keepAwake
        )
        profiles.append(profile)
        selectedProfileID = profile.id
    }

    func deleteProfile(_ profile: Profile) {
        profiles.removeAll { $0.id == profile.id }
        if selectedProfileID == profile.id {
            selectedProfileID = profiles.first?.id
        }
    }

    private static func defaultProfiles() -> [Profile] {
        [
            Profile(name: "Balanced", resolution: 1080, bitrate: 8_000_000, fps: 60, audioEnabled: true, fullscreen: false, mirrorMode: true, showTouches: false, keepAwake: true),
            Profile(name: "Smooth", resolution: 720, bitrate: 4_000_000, fps: 60, audioEnabled: false, fullscreen: false, mirrorMode: true, showTouches: false, keepAwake: true),
            Profile(name: "High Quality", resolution: 1440, bitrate: 12_000_000, fps: 60, audioEnabled: true, fullscreen: false, mirrorMode: true, showTouches: false, keepAwake: true)
        ]
    }
}

extension Notification.Name {
    static let launchScrcpy = Notification.Name("launchScrcpy")
    static let stopScrcpy = Notification.Name("stopScrcpy")
}

private struct AppPalette {
    static let bg = Color(nsColor: NSColor(red: 0.10, green: 0.12, blue: 0.16, alpha: 1.00))
    static let panel = Color(nsColor: NSColor(red: 0.15, green: 0.18, blue: 0.23, alpha: 1.00))
    static let panelStrong = Color(nsColor: NSColor(red: 0.19, green: 0.22, blue: 0.28, alpha: 1.00))
    static let border = Color(nsColor: NSColor(red: 0.38, green: 0.42, blue: 0.48, alpha: 0.45))
    static let accent = Color(nsColor: NSColor(red: 0.38, green: 0.78, blue: 0.82, alpha: 1.00))
    static let muted = Color(nsColor: NSColor(red: 0.76, green: 0.79, blue: 0.82, alpha: 1.00))
    static let success = Color(nsColor: NSColor(red: 0.33, green: 0.83, blue: 0.62, alpha: 1.00))
}

@main
struct SGRGPYApp: App {
    @StateObject private var settings = SettingsStore()
    @State private var showPreferences = false

    var body: some Scene {
        WindowGroup {
            ContentView(showPreferences: $showPreferences)
                .environmentObject(settings)
        }
        .commands {
            CommandMenu("SGRGPY") {
                Button("Preferences…") {
                    showPreferences = true
                }
                .keyboardShortcut(",", modifiers: [.command])

                Button("Connect") {
                    NotificationCenter.default.post(name: .launchScrcpy, object: nil)
                }
            }
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var settings: SettingsStore
    @Binding var showPreferences: Bool
    @State private var isRunning = false
    @State private var process: Process?

    var body: some View {
        ZStack(alignment: .top) {
            AppPalette.bg.ignoresSafeArea()

            VStack(spacing: 18) {
                titleBar
                    .padding(.horizontal, 16)
                    .padding(.top, 10)

                HStack(alignment: .top, spacing: 18) {
                    VStack(alignment: .leading, spacing: 15) {
                        devicePanel
                        modeButtons
                        navigationBar
                    }
                    .frame(maxWidth: 600, alignment: .leading)

                    VStack(alignment: .leading, spacing: 16) {
                        settingsCard(title: "Main parameters") {
                            VStack(spacing: 12) {
                                NumberSlider(label: "Resolution", value: $settings.resolution, range: 240...2160, step: 30)
                                NumberSlider(label: "Bitrate", value: $settings.bitrate, range: 100_000...40_000_000, step: 100_000)
                                NumberSlider(label: "FPS", value: $settings.fps, range: 15...120, step: 1)
                            }
                        }

                        settingsCard(title: "Quick toggles") {
                            VStack(alignment: .leading, spacing: 12) {
                                ToggleRow(label: "Audio", isOn: $settings.audioEnabled)
                                ToggleRow(label: "Show touches", isOn: $settings.showTouches)
                                ToggleRow(label: "Stay awake", isOn: $settings.keepAwake)
                                ToggleRow(label: "Fullscreen", isOn: $settings.fullscreen)
                                ToggleRow(label: "Record to file", isOn: $settings.recordEnabled)
                            }
                        }

                        HStack(spacing: 12) {
                            actionButton(title: isRunning ? "Stop" : "Connect", accent: !isRunning) {
                                if isRunning { stopScrcpy() } else { launchScrcpy() }
                            }
                            actionButton(title: "Open prefs", accent: false) {
                                showPreferences = true
                            }
                        }
                    }
                    .frame(maxWidth: 420, alignment: .leading)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 12)

                statusBar
                    .padding(.horizontal, 18)
                    .padding(.bottom, 10)
            }
        }
        .sheet(isPresented: $showPreferences) {
            PreferencesView(showSheet: $showPreferences)
                .environmentObject(settings)
        }
        .onReceive(NotificationCenter.default.publisher(for: .launchScrcpy)) { _ in
            launchScrcpy()
        }
        .onReceive(NotificationCenter.default.publisher(for: .stopScrcpy)) { _ in
            stopScrcpy()
        }
    }

    private var titleBar: some View {
        HStack(alignment: .center, spacing: 12) {
            HStack(spacing: 8) {
                Circle().fill(Color.red).frame(width: 12, height: 12)
                Circle().fill(Color.orange).frame(width: 12, height: 12)
                Circle().fill(Color.green).frame(width: 12, height: 12)
            }

            Text("SGRGPY")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)

            Spacer()

            HStack(spacing: 10) {
                Text("gui the f outta scrcpy")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppPalette.muted)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(AppPalette.panelStrong.cornerRadius(10))

            actionButton(title: isRunning ? "Running" : "Start", accent: true, compact: true) {
                if isRunning { stopScrcpy() } else { launchScrcpy() }
            }
        }
        .frame(height: 38)
    }

    private var devicePanel: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(LinearGradient(colors: [.black, Color(nsColor: NSColor(red: 0.20, green: 0.21, blue: 0.25, alpha: 1.00))], startPoint: .top, endPoint: .bottom))
                .frame(height: 360)
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .strokeBorder(AppPalette.border, lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(settings.mirrorMode ? "Device mirror" : "Extended display")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Capsule()
                        .fill(AppPalette.accent.opacity(0.18))
                        .frame(width: 68, height: 24)
                        .overlay(Text(settings.mirrorMode ? "Live" : "Window").font(.system(size: 11, weight: .semibold)).foregroundColor(AppPalette.accent))
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)

                Spacer()

                HStack(alignment: .bottom) {
                    Text("Android 14")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    Text("\(settings.resolution) × 1920")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 16)
            }
        }
    }

    private var modeButtons: some View {
        HStack(spacing: 10) {
            modeButton(title: "Mirror", active: settings.mirrorMode) {
                settings.mirrorMode = true
            }
            modeButton(title: "Extended", active: !settings.mirrorMode) {
                settings.mirrorMode = false
            }
        }
    }

    private var navigationBar: some View {
        HStack(spacing: 12) {
            navButton(icon: "clock.arrow.circlepath", label: "Recent")
            navButton(icon: "house.fill", label: "Home")
            navButton(icon: "arrow.uturn.left", label: "Back")
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(AppPalette.panelStrong.cornerRadius(18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(AppPalette.border, lineWidth: 1))
    }

    private var statusBar: some View {
        HStack(spacing: 14) {
            Label("Ready", systemImage: "circle.fill")
                .foregroundStyle(AppPalette.success)
                .font(.system(size: 12, weight: .semibold))

            Spacer()

            Text("scrcpy binary: \(scrcpyBinaryCandidate())")
                .foregroundStyle(AppPalette.muted)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(AppPalette.panelStrong.cornerRadius(14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppPalette.border, lineWidth: 1))
    }

    private func launchScrcpy() {
        guard let binaryURL = scrcpyBinaryURL() else {
            NSApp.presentError(alert: "scrcpy was not found. Install it via Homebrew or set SCRCPY_BIN.")
            return
        }

        let task = Process()
        task.executableURL = binaryURL
        task.arguments = buildScrcpyArguments()
        task.standardOutput = Pipe()
        task.standardError = Pipe()

        do {
            try task.run()
            process = task
            isRunning = true
            DispatchQueue.global().async {
                task.waitUntilExit()
                DispatchQueue.main.async {
                    isRunning = false
                    process = nil
                }
            }
        } catch {
            NSApp.presentError(alert: "Failed to start scrcpy: \(error.localizedDescription)")
        }
    }

    private func stopScrcpy() {
        process?.terminate()
        isRunning = false
        process = nil
    }

    private func buildScrcpyArguments() -> [String] {
        var args: [String] = []

        if !settings.deviceSerial.isEmpty {
            args += ["--serial", settings.deviceSerial]
        }

        if !settings.mirrorMode {
            args += ["--new-display"]
        }

        args += ["--max-size", String(settings.resolution)]
        args += ["--bit-rate", String(settings.bitrate)]
        args += ["--max-fps", String(settings.fps)]

        if !settings.audioEnabled { args += ["--no-audio"] }
        if settings.fullscreen { args += ["--fullscreen"] }
        if settings.showTouches { args += ["--show-touches"] }
        if settings.keepAwake { args += ["--stay-awake"] }

        if settings.recordEnabled {
            let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
            let filename = "sgrgpy-\(timestamp).mkv"
            let outputUrl = URL(fileURLWithPath: settings.pullDestination).appendingPathComponent(filename)
            args += ["--record", outputUrl.path]
        }

        args += ["--window-title", "SGRGPY"]
        return args
    }

    private func scrcpyBinaryCandidate() -> String {
        if let url = scrcpyBinaryURL() { return url.path }
        return "not found"
    }

    private func scrcpyBinaryURL() -> URL? {
        if let envPath = ProcessInfo.processInfo.environment["SCRCPY_BIN"], !envPath.isEmpty {
            return URL(fileURLWithPath: envPath)
        }

        let candidates = [
            "/opt/homebrew/bin/scrcpy",
            "/usr/local/bin/scrcpy",
            "/usr/local/opt/scrcpy/bin/scrcpy",
            "/opt/local/bin/scrcpy",
            NSHomeDirectory() + "/.local/bin/scrcpy"
        ]

        for candidate in candidates where FileManager.default.isExecutableFile(atPath: candidate) {
            return URL(fileURLWithPath: candidate)
        }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["-lc", "which scrcpy || true"]
        let outputPipe = Pipe()
        task.standardOutput = outputPipe
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()
            let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let path = output, !path.isEmpty, FileManager.default.isExecutableFile(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        } catch { }

        return nil
    }
}

private struct settingsCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppPalette.muted)
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppPalette.panelStrong.cornerRadius(18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(AppPalette.border, lineWidth: 1))
    }
}

private struct NumberSlider: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppPalette.muted)
                Spacer()
                TextField("", text: Binding(
                    get: { String(value) },
                    set: { newValue in
                        if let parsed = Int(newValue) {
                            value = min(max(parsed, range.lowerBound), range.upperBound)
                        }
                    }
                ))
                .frame(width: 96)
                .padding(6)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)
            }

            Slider(value: Binding(
                get: { Double(value) },
                set: { newValue in value = Int(newValue.rounded()) }
            ), in: Double(range.lowerBound)...Double(range.upperBound), step: Double(step))
            .accentColor(AppPalette.accent)
        }
    }
}

private struct ToggleRow: View {
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
        }
        .toggleStyle(SwitchToggleStyle(tint: AppPalette.accent))
    }
}

private struct modeButton: View {
    let title: String
    let active: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .foregroundStyle(active ? .black : .primary)
                .background(active ? AppPalette.accent : AppPalette.panelStrong)
                .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

private struct navButton: View {
    let icon: String
    let label: String

    var body: some View {
        Button(action: {}) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundStyle(.primary)
            .background(AppPalette.panel.cornerRadius(12))
        }
        .buttonStyle(.plain)
    }
}

private struct actionButton: View {
    let title: String
    let accent: Bool
    var compact: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: compact ? 11 : 13, weight: .semibold))
                .frame(minWidth: compact ? 84 : 120, minHeight: compact ? 26 : 36)
                .padding(.horizontal, compact ? 10 : 14)
                .foregroundStyle(accent ? .black : .primary)
                .background(accent ? AppPalette.accent : AppPalette.panelStrong)
                .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

extension NSApplication {
    func presentError(alert message: String) {
        let alert = NSAlert()
        alert.messageText = "SGRGPY"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

struct PreferencesView: View {
    @EnvironmentObject private var settings: SettingsStore
    @Binding var showSheet: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Preferences")
                    .font(.system(size: 22, weight: .bold))
                Spacer()
                Button("Close") {
                    showSheet = false
                }
            }

            Form {
                Section("Appearance") {
                    Picker("Look", selection: $settings.selectedAppearance) {
                        Text("Dark").tag("Dark")
                        Text("Light").tag("Light")
                        Text("System").tag("System")
                    }
                    .pickerStyle(.segmented)
                }

                Section("Pull destination") {
                    HStack {
                        TextField("Destination folder", text: $settings.pullDestination)
                        Button("Choose") {
                            let panel = NSOpenPanel()
                            panel.canChooseFiles = false
                            panel.canChooseDirectories = true
                            panel.allowsMultipleSelection = false
                            panel.begin { response in
                                if response == .OK, let url = panel.url {
                                    settings.pullDestination = url.path
                                }
                            }
                        }
                    }
                }

                Section("Profiles") {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(settings.profiles) { profile in
                            HStack {
                                Text(profile.name)
                                Spacer()
                                Button("Use") {
                                    settings.applyProfile(profile)
                                }
                                Button("Delete", role: .destructive) {
                                    settings.deleteProfile(profile)
                                }
                            }
                        }

                        Button("Save current as preset") {
                            settings.saveCurrentAsProfile()
                        }
                    }
                }

                Section("Advanced") {
                    ToggleRow(label: "Audio enabled", isOn: $settings.audioEnabled)
                    ToggleRow(label: "Fullscreen", isOn: $settings.fullscreen)
                    ToggleRow(label: "Mirror mode", isOn: $settings.mirrorMode)
                    ToggleRow(label: "Keep awake", isOn: $settings.keepAwake)
                }
            }
            .formStyle(.automatic)
        }
        .padding(20)
        .frame(width: 540, height: 560)
    }
}
