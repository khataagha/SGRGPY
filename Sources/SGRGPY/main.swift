import AppKit
import Foundation
import SwiftUI

// SGRGPY is a native front-end for the upstream scrcpy executable. scrcpy
// remains a separately installed dependency; this app does not fork or bundle it.

struct AndroidDevice: Identifiable, Hashable {
    let serial: String
    let details: String
    var id: String { serial }
}

struct StreamProfile: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var resolution: Int
    var bitrate: Int
    var fps: Int
    var audioEnabled: Bool
    var showTouches: Bool
    var stayAwake: Bool
}

struct PersistedSettings: Codable {
    var appearance = "System"
    var destination = "~/Downloads"
    var resolution = 1080
    var bitrate = 8_000_000
    var fps = 60
    var audioEnabled = true
    var showTouches = false
    var stayAwake = true
    var record = false
    var profiles: [StreamProfile] = []
}

@MainActor
final class AppModel: ObservableObject {
    @Published var devices: [AndroidDevice] = []
    @Published var selectedSerial = ""
    @Published var status = "Connect an Android device with USB debugging enabled."
    @Published var isRefreshing = false
    @Published var isRunning = false
    @Published var appearance: String { didSet { save() } }
    @Published var destination: String { didSet { save() } }
    @Published var resolution: Int { didSet { save() } }
    @Published var bitrate: Int { didSet { save() } }
    @Published var fps: Int { didSet { save() } }
    @Published var audioEnabled: Bool { didSet { save() } }
    @Published var showTouches: Bool { didSet { save() } }
    @Published var stayAwake: Bool { didSet { save() } }
    @Published var record: Bool { didSet { save() } }
    @Published var profiles: [StreamProfile] { didSet { save() } }

    private let settingsURL: URL
    private var scrcpyProcess: Process?
    private var loading = true

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SGRGPY", isDirectory: true)
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        settingsURL = support.appendingPathComponent("settings.json")
        let saved = (try? Data(contentsOf: settingsURL)).flatMap { try? JSONDecoder().decode(PersistedSettings.self, from: $0) } ?? PersistedSettings()
        appearance = saved.appearance
        destination = saved.destination
        resolution = saved.resolution
        bitrate = saved.bitrate
        fps = saved.fps
        audioEnabled = saved.audioEnabled
        showTouches = saved.showTouches
        stayAwake = saved.stayAwake
        record = saved.record
        profiles = saved.profiles.isEmpty ? Self.defaultProfiles : saved.profiles
        loading = false
    }

    private static let defaultProfiles = [
        StreamProfile(name: "Balanced", resolution: 1080, bitrate: 8_000_000, fps: 60, audioEnabled: true, showTouches: false, stayAwake: true),
        StreamProfile(name: "Smooth", resolution: 720, bitrate: 4_000_000, fps: 60, audioEnabled: true, showTouches: false, stayAwake: true),
        StreamProfile(name: "High quality", resolution: 1440, bitrate: 16_000_000, fps: 60, audioEnabled: true, showTouches: false, stayAwake: true)
    ]

    private func save() {
        guard !loading else { return }
        let saved = PersistedSettings(appearance: appearance, destination: destination,
            resolution: resolution, bitrate: bitrate, fps: fps,
            audioEnabled: audioEnabled, showTouches: showTouches,
            stayAwake: stayAwake, record: record, profiles: profiles)
        guard let data = try? JSONEncoder().encode(saved) else { return }
        try? data.write(to: settingsURL, options: .atomic)
    }

    func apply(_ profile: StreamProfile) {
        resolution = profile.resolution
        bitrate = profile.bitrate
        fps = profile.fps
        audioEnabled = profile.audioEnabled
        showTouches = profile.showTouches
        stayAwake = profile.stayAwake
    }

    func saveProfile() {
        let profile = StreamProfile(name: "Preset \(profiles.count + 1)", resolution: resolution,
            bitrate: bitrate, fps: fps, audioEnabled: audioEnabled,
            showTouches: showTouches, stayAwake: stayAwake)
        profiles.append(profile)
    }

    func refreshDevices() {
        guard !isRefreshing else { return }
        guard let adb = Self.findExecutable(named: "adb") else {
            devices = []
            status = "ADB not found. Install Android platform-tools, then refresh."
            return
        }
        isRefreshing = true
        status = "Looking for Android devices…"
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = Self.capture(adb, arguments: ["devices", "-l"])
            DispatchQueue.main.async {
                guard let self else { return }
                self.isRefreshing = false
                guard result.status == 0 else {
                    self.devices = []
                    self.status = result.output.isEmpty ? "ADB could not list devices." : result.output
                    return
                }
                let found = result.output.split(whereSeparator: \.isNewline).compactMap { line -> AndroidDevice? in
                    let text = String(line)
                    guard !text.hasPrefix("List of devices"),
                          let range = text.range(of: #"^([^\s]+)\s+device(?:\s|$)"#, options: .regularExpression) else { return nil }
                    let serial = String(text[range]).split(whereSeparator: \.isWhitespace).first.map(String.init) ?? ""
                    guard !serial.isEmpty else { return nil }
                    return AndroidDevice(serial: serial, details: text)
                }
                self.devices = found
                if !self.selectedSerial.isEmpty && !found.contains(where: { $0.serial == self.selectedSerial }) {
                    self.selectedSerial = ""
                }
                if self.selectedSerial.isEmpty && found.count == 1 {
                    self.selectedSerial = found[0].serial
                }
                self.status = found.isEmpty ? "No authorized devices found. Check the USB debugging prompt on your phone." : "\(found.count) device\(found.count == 1 ? "" : "s") ready."
            }
        }
    }

    func start() {
        guard !isRunning else { return }
        guard let scrcpy = Self.findExecutable(named: "scrcpy") else {
            status = "scrcpy not found. Install it with Homebrew or set SCRCPY_BIN."
            return
        }
        guard !selectedSerial.isEmpty else {
            status = "Select an authorized Android device first."
            return
        }
        if record {
            let folder = (destination as NSString).expandingTildeInPath
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: folder, isDirectory: &isDirectory), isDirectory.boolValue else {
                status = "Recording folder does not exist. Choose a valid destination in Preferences."
                return
            }
        }

        let task = Process()
        task.executableURL = scrcpy
        task.arguments = makeArguments()
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        var environment = ProcessInfo.processInfo.environment
        var paths = (environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin").components(separatedBy: ":")
        for url in [scrcpy, Self.findExecutable(named: "adb")].compactMap({ $0 }) {
            let parent = url.deletingLastPathComponent().path
            if !paths.contains(parent) { paths.insert(parent, at: 0) }
        }
        environment["PATH"] = paths.joined(separator: ":")
        task.environment = environment
        task.terminationHandler = { [weak self] process in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isRunning = false
                self.scrcpyProcess = nil
                self.status = process.terminationStatus == 0 ? "scrcpy session ended." : "scrcpy exited with code \(process.terminationStatus). Check device connection and scrcpy installation."
            }
        }
        do {
            try task.run()
            scrcpyProcess = task
            isRunning = true
            status = "Mirroring \(selectedSerial). scrcpy opens its own native video window."
        } catch {
            status = "Could not launch scrcpy: \(error.localizedDescription)"
        }
    }

    func stop() {
        guard let process = scrcpyProcess, process.isRunning else { return }
        process.terminate()
        status = "Stopping scrcpy…"
    }

    func sendNavigation(_ keyCode: String) {
        guard !selectedSerial.isEmpty, let adb = Self.findExecutable(named: "adb") else {
            status = "Choose an authorized device before sending navigation keys."
            return
        }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = Self.capture(adb, arguments: ["-s", self?.selectedSerial ?? "", "shell", "input", "keyevent", keyCode])
            DispatchQueue.main.async {
                if result.status == 0 { self?.status = "Sent Android navigation command." }
                else { self?.status = result.output.isEmpty ? "ADB navigation command failed." : result.output }
            }
        }
    }

    private func makeArguments() -> [String] {
        var args = ["--serial", selectedSerial,
                    "--max-size", String(resolution),
                    "--video-bit-rate", String(bitrate),
                    "--max-fps", String(fps),
                    "--window-title", "SGRGPY — \(selectedSerial)"]
        if !audioEnabled { args.append("--no-audio") }
        if showTouches { args.append("--show-touches") }
        if stayAwake { args.append("--stay-awake") }
        if !mirrorMode { args.append("--new-display") }
        if record {
            let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
            let file = URL(fileURLWithPath: (destination as NSString).expandingTildeInPath).appendingPathComponent("sgrgpy-\(stamp).mkv")
            args += ["--record", file.path]
        }
        return args
    }

    var mirrorMode = true

    private static func findExecutable(named name: String) -> URL? {
        if name == "scrcpy", let configured = ProcessInfo.processInfo.environment["SCRCPY_BIN"],
           FileManager.default.isExecutableFile(atPath: configured) { return URL(fileURLWithPath: configured) }
        let known = name == "adb"
            ? ["/opt/homebrew/bin/adb", "/usr/local/bin/adb", "/opt/local/bin/adb", "/usr/bin/adb"]
            : ["/opt/homebrew/bin/scrcpy", "/usr/local/bin/scrcpy", "/usr/local/opt/scrcpy/bin/scrcpy", "/opt/local/bin/scrcpy"]
        for path in known where FileManager.default.isExecutableFile(atPath: path) { return URL(fileURLWithPath: path) }
        let pathValue = ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        for directory in pathValue.split(separator: ":") {
            let path = URL(fileURLWithPath: String(directory)).appendingPathComponent(name).path
            if FileManager.default.isExecutableFile(atPath: path) { return URL(fileURLWithPath: path) }
        }
        return nil
    }

    private static func capture(_ executable: URL, arguments: [String]) -> (status: Int32, output: String) {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = executable
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return (process.terminationStatus, String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
        } catch {
            return (-1, error.localizedDescription)
        }
    }
}

@main
struct SGRGPYApp: App {
    @StateObject private var model = AppModel()
    @State private var showPreferences = false

    var body: some Scene {
        WindowGroup {
            MainView(showPreferences: $showPreferences)
                .environmentObject(model)
                .preferredColorScheme(model.appearance == "Light" ? .light : model.appearance == "Dark" ? .dark : nil)
                .frame(minWidth: 820, minHeight: 620)
                .task { model.refreshDevices() }
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Preferences…") { showPreferences = true }
                    .keyboardShortcut(",", modifiers: [.command])
            }
        }
    }
}

struct MainView: View {
    @EnvironmentObject private var model: AppModel
    @Binding var showPreferences: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            HStack(alignment: .top, spacing: 20) {
                VStack(spacing: 16) {
                    preview
                    navigation
                }
                .frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 16) {
                    devicePicker
                    parameterCard
                    optionsCard
                    HStack {
                        Button(action: { showPreferences = true }) { Label("Preferences", systemImage: "slider.horizontal.3") }
                            .buttonStyle(.bordered)
                        Spacer()
                        Button(action: { model.isRunning ? model.stop() : model.start() }) {
                            Label(model.isRunning ? "Stop mirroring" : "Start mirroring", systemImage: model.isRunning ? "stop.fill" : "play.fill")
                                .frame(minWidth: 145)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.accentColor)
                    }
                }
                .frame(width: 350)
            }
            .padding(22)
            Spacer(minLength: 0)
            statusBar
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $showPreferences) { PreferencesView().environmentObject(model) }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "rectangle.on.rectangle")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text("SGRGPY").font(.system(size: 16, weight: .bold, design: .rounded))
                Text("gui the f outta scrcpy").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if model.isRefreshing { ProgressView().controlSize(.small) }
            Button { model.refreshDevices() } label: { Label("Refresh devices", systemImage: "arrow.clockwise") }
                .buttonStyle(.bordered)
                .disabled(model.isRefreshing)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
        .background(.bar)
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(model.mirrorMode ? "Device mirror" : "Extended display", systemImage: model.mirrorMode ? "iphone" : "macbook.and.iphone")
                    .font(.headline)
                Spacer()
                Circle().fill(model.isRunning ? Color.green : Color.secondary.opacity(0.5)).frame(width: 8, height: 8)
                Text(model.isRunning ? "Running" : "Not started").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "iphone.gen3")
                .font(.system(size: 74, weight: .ultraLight))
                .foregroundStyle(.secondary.opacity(0.55))
            Text(model.selectedSerial.isEmpty ? "Select an Android device to begin" : model.selectedSerial)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Text("The live video appears in scrcpy’s own native window.")
                .font(.caption).foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 380)
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.secondary.opacity(0.15)))
    }

    private var navigation: some View {
        HStack(spacing: 12) {
            navButton("Recent", icon: "square.stack.3d.up", key: "KEYCODE_APP_SWITCH")
            navButton("Home", icon: "house", key: "KEYCODE_HOME")
            navButton("Back", icon: "chevron.left", key: "KEYCODE_BACK")
        }
    }

    private func navButton(_ title: String, icon: String, key: String) -> some View {
        Button { model.sendNavigation(key) } label: {
            Label(title, systemImage: icon).frame(maxWidth: .infinity, minHeight: 38)
        }
        .buttonStyle(.bordered)
        .disabled(model.selectedSerial.isEmpty)
        .help("Send Android \(title) key using ADB")
    }

    private var devicePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DEVICE").font(.caption2.weight(.bold)).foregroundStyle(.secondary)
            Picker("Android device", selection: $model.selectedSerial) {
                Text("Choose a device…").tag("")
                ForEach(model.devices) { device in
                    Text(device.serial).tag(device.serial)
                }
            }
            .labelsHidden()
            .disabled(model.devices.isEmpty)
            if model.devices.isEmpty {
                Text("Enable USB debugging, accept the prompt, then refresh.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(cardBackground)
    }

    private var parameterCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Stream quality").font(.headline)
            parameter("Resolution", value: $model.resolution, range: 240...2160, step: 30, suffix: " px")
            parameter("Bitrate", value: $model.bitrate, range: 1_000_000...40_000_000, step: 1_000_000, suffix: " bps")
            parameter("Frame rate", value: $model.fps, range: 15...120, step: 1, suffix: " fps")
        }
        .padding(14)
        .background(cardBackground)
    }

    private func parameter(_ title: String, value: Binding<Int>, range: ClosedRange<Int>, step: Int, suffix: String) -> some View {
        VStack(spacing: 5) {
            HStack {
                Text(title).font(.subheadline)
                Spacer()
                TextField(title, value: value, format: .number.grouping(.never))
                    .frame(width: 88)
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.roundedBorder)
                Text(suffix).font(.caption).foregroundStyle(.secondary).frame(width: 48, alignment: .leading)
            }
            Slider(value: Binding(get: { Double(value.wrappedValue) }, set: { value.wrappedValue = Int($0.rounded()) }), in: Double(range.lowerBound)...Double(range.upperBound), step: Double(step))
                .tint(Color.accentColor)
        }
    }

    private var optionsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Options").font(.headline)
            Toggle("Audio", isOn: $model.audioEnabled)
            Toggle("Show touches", isOn: $model.showTouches)
            Toggle("Keep device awake", isOn: $model.stayAwake)
            Toggle("Record session", isOn: $model.record)
        }
        .toggleStyle(.switch)
        .padding(14)
        .background(cardBackground)
    }

    private var statusBar: some View {
        HStack(spacing: 8) {
            Image(systemName: model.isRunning ? "circle.fill" : "info.circle")
                .foregroundStyle(model.isRunning ? .green : .secondary)
            Text(model.status).lineLimit(1)
            Spacer()
            Text("macOS 12+").foregroundStyle(.tertiary)
        }
        .font(.caption)
        .padding(.horizontal, 22)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 14).fill(Color(nsColor: .controlBackgroundColor))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.secondary.opacity(0.12)))
    }
}

struct PreferencesView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Preferences").font(.title2.bold())
                    Text("Tune the app and manage your presets.").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: $model.appearance) {
                        Text("System").tag("System")
                        Text("Light").tag("Light")
                        Text("Dark").tag("Dark")
                    }
                    .pickerStyle(.segmented)
                }
                Section("Recording destination") {
                    HStack {
                        TextField("~/Downloads", text: $model.destination)
                        Button("Choose…") {
                            let panel = NSOpenPanel()
                            panel.canChooseFiles = false
                            panel.canChooseDirectories = true
                            panel.allowsMultipleSelection = false
                            panel.begin { if $0 == .OK, let url = panel.url { model.destination = url.path } }
                        }
                    }
                    Text("Recording files are saved here as MKV. This folder does not change ADB pull behavior.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Presets") {
                    ForEach(model.profiles) { profile in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(profile.name).font(.subheadline.weight(.medium))
                                Text("\(profile.resolution)p · \(profile.bitrate / 1_000_000) Mbps · \(profile.fps) FPS")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Apply") { model.apply(profile) }
                            Button(role: .destructive) { model.profiles.removeAll { $0.id == profile.id } } label: {
                                Image(systemName: "trash")
                            }
                            .help("Delete preset")
                        }
                    }
                    Button { model.saveProfile() } label: { Label("Save current settings as preset", systemImage: "plus") }
                }
            }
            .formStyle(.grouped)
        }
        .padding(22)
        .frame(width: 560, height: 560)
    }
}
