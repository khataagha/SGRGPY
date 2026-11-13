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
    let bg: Color
    let panel: Color
    let panelStrong: Color
    let border: Color
    let accent: Color
    let muted: Color
    let success: Color
    let primaryText: Color
    let secondaryText: Color
    let buttonText: Color
    let ghost: Color

    static func resolved(theme: String, colorScheme: ColorScheme) -> AppPalette {
        let isDark: Bool
        switch theme {
        case "Light": isDark = false
        case "System": isDark = colorScheme == .dark
        default: isDark = true
        }

        if isDark {
            return AppPalette(
                bg: Color(nsColor: NSColor(red: 0.10, green: 0.12, blue: 0.16, alpha: 1.00)),
                panel: Color(nsColor: NSColor(red: 0.15, green: 0.18, blue: 0.23, alpha: 1.00)),
                panelStrong: Color(nsColor: NSColor(red: 0.19, green: 0.22, blue: 0.28, alpha: 1.00)),
                border: Color(nsColor: NSColor(red: 0.38, green: 0.42, blue: 0.48, alpha: 0.45)),
                accent: Color(nsColor: NSColor(red: 0.38, green: 0.78, blue: 0.82, alpha: 1.00)),
                muted: Color(nsColor: NSColor(red: 0.76, green: 0.79, blue: 0.82, alpha: 1.00)),
                success: Color(nsColor: NSColor(red: 0.33, green: 0.83, blue: 0.62, alpha: 1.00)),
                primaryText: .white,
                secondaryText: Color(nsColor: NSColor(red: 0.87, green: 0.90, blue: 0.94, alpha: 1.00)),
                buttonText: .black,
                ghost: Color(nsColor: NSColor(red: 0.12, green: 0.15, blue: 0.20, alpha: 1.00))
            )
        }

        return AppPalette(
            bg: Color(nsColor: NSColor(red: 0.96, green: 0.97, blue: 0.98, alpha: 1.00)),
            panel: Color(nsColor: NSColor(red: 0.94, green: 0.96, blue: 0.98, alpha: 1.00)),
            panelStrong: Color(nsColor: NSColor(red: 0.90, green: 0.93, blue: 0.96, alpha: 1.00)),
            border: Color(nsColor: NSColor(red: 0.73, green: 0.78, blue: 0.84, alpha: 1.00)),
            accent: Color(nsColor: NSColor(red: 0.21, green: 0.70, blue: 0.76, alpha: 1.00)),
            muted: Color(nsColor: NSColor(red: 0.34, green: 0.38, blue: 0.44, alpha: 1.00)),
            success: Color(nsColor: NSColor(red: 0.26, green: 0.74, blue: 0.52, alpha: 1.00)),
            primaryText: .black,
            secondaryText: Color(nsColor: NSColor(red: 0.25, green: 0.29, blue: 0.32, alpha: 1.00)),
            buttonText: .white,
            ghost: Color(nsColor: NSColor(red: 0.99, green: 0.99, blue: 1.00, alpha: 1.00))
        )
    }
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
    @Environment(\.colorScheme) private var colorScheme
    @Binding var showPreferences: Bool
    @State private var isRunning = false
    @State private var process: Process?

    private var palette: AppPalette { AppPalette.resolved(theme: settings.selectedAppearance, colorScheme: colorScheme) }

    var body: some View {
        ZStack(alignment: .top) {
            palette.bg.ignoresSafeArea()

            VStack(spacing: 18) {
                titleBar(palette: palette)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)

                HStack(alignment: .top, spacing: 18) {
                    VStack(alignment: .leading, spacing: 15) {
                        devicePanel(palette: palette)
                        modeButtons(palette: palette)
                        navigationBar(palette: palette)
                    }
                    .frame(maxWidth: 600, alignment: .leading)

                    VStack(alignment: .leading, spacing: 16) {
                        settingsCard(title: "Main parameters", palette: palette) {
                            VStack(spacing: 12) {
                                NumberSlider(label: "Resolution", value: $settings.resolution, range: 240...2160, step: 30, palette: palette)
                                NumberSlider(label: "Bitrate", value: $settings.bitrate, range: 100_000...40_000_000, step: 100_000, palette: palette)
                                NumberSlider(label: "FPS", value: $settings.fps, range: 15...120, step: 1, palette: palette)
                            }
                        }

                        settingsCard(title: "Quick toggles", palette: palette) {
                            VStack(alignment: .leading, spacing: 12) {
                                ToggleRow(label: "Audio", isOn: $settings.audioEnabled, palette: palette)
                                ToggleRow(label: "Show touches", isOn: $settings.showTouches, palette: palette)
                                ToggleRow(label: "Stay awake", isOn: $settings.keepAwake, palette: palette)
                                ToggleRow(label: "Fullscreen", isOn: $settings.fullscreen, palette: palette)
                                ToggleRow(label: "Record to file", isOn: $settings.recordEnabled, palette: palette)
                            }
                        }

                        HStack(spacing: 12) {
                            actionButton(title: isRunning ? "Stop" : "Connect", accent: !isRunning, palette: palette) {
                                if isRunning { stopScrcpy() } else { launchScrcpy() }
                            }
                            actionButton(title: "Open prefs", accent: false, palette: palette) {
                                showPreferences = true
                            }
                        }
                    }
                    .frame(maxWidth: 420, alignment: .leading)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 12)

                statusBar(palette: palette)
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

    private func titleBar(palette: AppPalette) -> some View {
        HStack(alignment: .center, spacing: 12) {
            HStack(spacing: 8) {
                Circle().fill(Color.red).frame(width: 12, height: 12)
                Circle().fill(Color.orange).frame(width: 12, height: 12)
                Circle().fill(Color.green).frame(width: 12, height: 12)
            }

            Text("SGRGPY")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(palette.primaryText)

            Spacer()

            HStack(spacing: 10) {
                Text("gui the f outta scrcpy")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(palette.muted)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(palette.panelStrong.cornerRadius(10))

            actionButton(title: isRunning ? "Running" : "Start", accent: true, compact: true, palette: palette) {
                if isRunning { stopScrcpy() } else { launchScrcpy() }
            }
        }
        .frame(height: 38)
    }

    private func devicePanel(palette: AppPalette) -> some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(LinearGradient(colors: [.black, Color(nsColor: NSColor(red: 0.20, green: 0.21, blue: 0.25, alpha: 1.00))], startPoint: .top, endPoint: .bottom))
                .frame(height: 360)
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .strokeBorder(palette.border, lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(settings.mirrorMode ? "Device mirror" : "Extended display")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Capsule()
                        .fill(palette.accent.opacity(0.18))
                        .frame(width: 68, height: 24)
                        .overlay(Text(settings.mirrorMode ? "Live" : "Window").font(.system(size: 11, weight: .semibold)).foregroundColor(palette.accent))
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

    private func modeButtons(palette: AppPalette) -> some View {
        HStack(spacing: 10) {
            modeButton(title: "Mirror", active: settings.mirrorMode, palette: palette) {
                settings.mirrorMode = true
            }
            modeButton(title: "Extended", active: !settings.mirrorMode, palette: palette) {
                settings.mirrorMode = false
            }
        }
    }

    private func navigationBar(palette: AppPalette) -> some View {
        HStack(spacing: 12) {
            navButton(icon: "clock.arrow.circlepath", label: "Recent", palette: palette)
            navButton(icon: "house.fill", label: "Home", palette: palette)
            navButton(icon: "arrow.uturn.left", label: "Back", palette: palette)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(palette.panelStrong.cornerRadius(18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(palette.border, lineWidth: 1))
    }

    private func statusBar(palette: AppPalette) -> some View {
        HStack(spacing: 14) {
            Label("Ready", systemImage: "circle.fill")
                .foregroundStyle(palette.success)
                .font(.system(size: 12, weight: .semibold))

            Spacer()

            Text("scrcpy binary: \(scrcpyBinaryCandidate())")
                .foregroundStyle(palette.muted)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(palette.panelStrong.cornerRadius(14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(palette.border, lineWidth: 1))
    }

    private func launchScrcpy() {
        guard let binaryURL = scrcpyBinaryURL() else {
            NSApp.presentError(alert: "scrcpy was not found. Install via Homebrew or set SCRCPY_BIN.")
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
            let outputURL = URL(fileURLWithPath: settings.pullDestination).appendingPathComponent(filename)
            args += ["--record", outputURL.path]
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
        } catch {}

        return nil
    }
}

private struct settingsCard<Content: View>: View {
    let title: String
    let palette: AppPalette
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(palette.muted)
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.panelStrong.cornerRadius(18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(palette.border, lineWidth: 1))
    }
}

private struct NumberSlider: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    let palette: AppPalette

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(palette.muted)
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
                .foregroundStyle(palette.primaryText)
            }

            Slider(value: Binding(
                get: { Double(value) },
                set: { newValue in value = Int(newValue.rounded()) }
            ), in: Double(range.lowerBound)...Double(range.upperBound), step: Double(step))
            .accentColor(palette.accent)
        }
    }
}

private struct ToggleRow: View {
    let label: String
    @Binding var isOn: Bool
    let palette: AppPalette

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(palette.primaryText)
        }
        .toggleStyle(SwitchToggleStyle(tint: palette.accent))
    }
}

private struct modeButton: View {
    let title: String
    let active: Bool
    let palette: AppPalette
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .foregroundStyle(active ? palette.buttonText : palette.primaryText)
                .background(active ? palette.accent : palette.panelStrong)
                .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

private struct navButton: View {
    let icon: String
    let label: String
    let palette: AppPalette

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
            .foregroundStyle(palette.primaryText)
            .background(palette.panel.cornerRadius(12))
        }
        .buttonStyle(.plain)
    }
}

private struct actionButton: View {
    let title: String
    let accent: Bool
    let palette: AppPalette
    var compact: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: compact ? 11 : 13, weight: .semibold))
                .frame(minWidth: compact ? 84 : 120, minHeight: compact ? 26 : 36)
                .padding(.horizontal, compact ? 10 : 14)
                .foregroundStyle(accent ? palette.buttonText : palette.primaryText)
                .background(accent ? palette.accent : palette.panelStrong)
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
    @Environment(\.colorScheme) private var colorScheme
    @Binding var showSheet: Bool

    private var palette: AppPalette { AppPalette.resolved(theme: settings.selectedAppearance, colorScheme: colorScheme) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Preferences")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(palette.primaryText)
                Spacer()
                Button("Close") {
                    showSheet = false
                }
                .foregroundStyle(palette.primaryText)
            }

            Form {
                Section("Appearance") {
                    Picker("Look", selection: $settings.selectedAppearance) {
                        Text("Dark").tag("Dark")
                        Text("Light").tag("Light")
                        Text("System").tag("System")
                    }
                    .pickerStyle(.segmented)
                    .tint(palette.accent)
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
                    ToggleRow(label: "Audio enabled", isOn: $settings.audioEnabled, palette: palette)
                    ToggleRow(label: "Fullscreen", isOn: $settings.fullscreen, palette: palette)
                    ToggleRow(label: "Mirror mode", isOn: $settings.mirrorMode, palette: palette)
                    ToggleRow(label: "Keep awake", isOn: $settings.keepAwake, palette: palette)
                }
            }
            .formStyle(.automatic)
            .background(palette.bg)
        }
        .padding(20)
        .frame(width: 540, height: 560)
        .background(palette.bg)
    }
}

#warning("This project is a native macOS frontend for scrcpy. It intentionally launches the upstream scrcpy binary rather than reimplementing it.")
