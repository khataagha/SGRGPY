import AppKit
import Foundation
import SwiftUI

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
    var mirrorMode: Bool
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
    var mirrorMode = true
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
    @Published var mirrorMode: Bool { didSet { save() } }
    @Published var profiles: [StreamProfile] { didSet { save() } }

    private let settingsURL: URL
    private var scrcpyProcess: Process?
    private var isLoading = true

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SGRGPY", isDirectory: true)
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        settingsURL = support.appendingPathComponent("settings.json")
        let saved = (try? Data(contentsOf: settingsURL)).flatMap {
            try? JSONDecoder().decode(PersistedSettings.self, from: $0)
        } ?? PersistedSettings()
        appearance = saved.appearance
        destination = saved.destination
        resolution = saved.resolution
        bitrate = saved.bitrate
        fps = saved.fps
        audioEnabled = saved.audioEnabled
        showTouches = saved.showTouches
        stayAwake = saved.stayAwake
        record = saved.record
        mirrorMode = saved.mirrorMode
        profiles = saved.profiles.isEmpty ? Self.defaultProfiles : saved.profiles
        isLoading = false
    }

    private static let defaultProfiles = [
        StreamProfile(name: "Balanced", resolution: 1080, bitrate: 8_000_000, fps: 60, audioEnabled: true, showTouches: false, stayAwake: true, mirrorMode: true),
        StreamProfile(name: "Smooth", resolution: 720, bitrate: 4_000_000, fps: 60, audioEnabled: true, showTouches: false, stayAwake: true, mirrorMode: true),
        StreamProfile(name: "High quality", resolution: 1440, bitrate: 16_000_000, fps: 60, audioEnabled: true, showTouches: false, stayAwake: true, mirrorMode: true)
    ]

    private func save() {
        guard !isLoading else { return }
        let dataModel = PersistedSettings(appearance: appearance, destination: destination,
            resolution: resolution, bitrate: bitrate, fps: fps, audioEnabled: audioEnabled,
            showTouches: showTouches, stayAwake: stayAwake, record: record,
            mirrorMode: mirrorMode, profiles: profiles)
        guard let data = try? JSONEncoder().encode(dataModel) else { return }
        try? data.write(to: settingsURL, options: .atomic)
    }

    func apply(_ profile: StreamProfile) {
        resolution = profile.resolution
        bitrate = profile.bitrate
        fps = profile.fps
        audioEnabled = profile.audioEnabled
        showTouches = profile.showTouches
        stayAwake = profile.stayAwake
        mirrorMode = profile.mirrorMode
    }

    func saveProfile(name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        profiles.append(StreamProfile(name: trimmedName, resolution: resolution, bitrate: bitrate,
            fps: fps, audioEnabled: audioEnabled, showTouches: showTouches,
            stayAwake: stayAwake, mirrorMode: mirrorMode))
    }

    func refreshDevices() {
        guard !isRefreshing else { return }
        guard let adb = runtimeExecutable("adb") else {
            status = "Bundled ADB is missing. Rebuild the app bundle."
            return
        }
        isRefreshing = true
        status = "Looking for Android devices…"
        Task.detached(priority: .userInitiated) { [weak self] in
            let result = Self.capture(adb, arguments: ["devices", "-l"])
            await MainActor.run {
                guard let self else { return }
                self.isRefreshing = false
                guard result.status == 0 else {
                    self.devices = []
                    self.status = result.output.isEmpty ? "ADB could not list devices." : result.output
                    return
                }
                let found = result.output.split(whereSeparator: \.isNewline).compactMap { line -> AndroidDevice? in
                    let columns = line.split(whereSeparator: \.isWhitespace).map(String.init)
                    guard columns.count >= 2, columns[1] == "device" else { return nil }
                    return AndroidDevice(serial: columns[0], details: String(line))
                }
                self.devices = found
                if !found.contains(where: { $0.serial == self.selectedSerial }) { self.selectedSerial = "" }
                if self.selectedSerial.isEmpty && found.count == 1 { self.selectedSerial = found[0].serial }
                self.status = found.isEmpty ? "No authorized devices found. Check the USB debugging prompt." : "\(found.count) device\(found.count == 1 ? "" : "s") ready."
            }
        }
    }

    func start() {
        guard !isRunning else { return }
        guard let scrcpy = runtimeExecutable("scrcpy"), let adb = runtimeExecutable("adb") else {
            status = "Bundled scrcpy runtime is missing. Rebuild the app bundle."
            return
        }
        guard !selectedSerial.isEmpty else {
            status = "Select an authorized Android device first."
            return
        }
        let outputFolder = URL(fileURLWithPath: (destination as NSString).expandingTildeInPath, isDirectory: true)
        if record {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: outputFolder.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                status = "Recording folder does not exist. Choose a valid destination in Preferences."
                return
            }
        }

        let task = Process()
        task.executableURL = scrcpy
        task.arguments = makeArguments(outputFolder: outputFolder)
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        var environment = ProcessInfo.processInfo.environment
        environment["ADB"] = adb.path
        environment["SCRCPY_SERVER_PATH"] = runtimeDirectory.appendingPathComponent("scrcpy-server").path
        environment["SCRCPY_ICON_DIR"] = runtimeDirectory.path
        environment["PATH"] = runtimeDirectory.path + ":" + (environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin")
        task.environment = environment
        task.terminationHandler = { [weak self] process in
            Task { @MainActor in
                guard let self else { return }
                self.isRunning = false
                self.scrcpyProcess = nil
                self.status = process.terminationStatus == 0 ? "scrcpy session ended." : "scrcpy exited with code \(process.terminationStatus)."
            }
        }
        do {
            try task.run()
            scrcpyProcess = task
            isRunning = true
            status = "Mirroring \(selectedSerial). The video window is provided by bundled scrcpy."
        } catch {
            status = "Could not launch bundled scrcpy: \(error.localizedDescription)"
        }
    }

    func stop() {
        guard let process = scrcpyProcess, process.isRunning else { return }
        process.terminate()
        status = "Stopping scrcpy…"
    }

    func sendNavigation(_ keyCode: String) {
        guard !selectedSerial.isEmpty, let adb = runtimeExecutable("adb") else {
            status = "Choose an authorized device first."
            return
        }
        let serial = selectedSerial
        Task.detached(priority: .userInitiated) { [weak self] in
            let result = Self.capture(adb, arguments: ["-s", serial, "shell", "input", "keyevent", keyCode])
            await MainActor.run {
                self?.status = result.status == 0 ? "Sent Android navigation command." : "ADB navigation failed: \(result.output)"
            }
        }
    }

    private func makeArguments(outputFolder: URL) -> [String] {
        var args = ["--serial", selectedSerial, "--max-size", String(resolution),
                    "--video-bit-rate", String(bitrate), "--max-fps", String(fps),
                    "--window-title", "SGRGPY — \(selectedSerial)"]
        if !audioEnabled { args.append("--no-audio") }
        if showTouches { args.append("--show-touches") }
        if stayAwake { args.append("--stay-awake") }
        if !mirrorMode { args.append("--new-display") }
        if record {
            let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
            args += ["--record", outputFolder.appendingPathComponent("sgrgpy-\(stamp).mkv").path]
        }
        return args
    }

    private var runtimeDirectory: URL {
        Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/scrcpy-runtime", isDirectory: true)
    }

    private func runtimeExecutable(_ name: String) -> URL? {
        #if DEBUG
        if let configured = ProcessInfo.processInfo.environment[name == "scrcpy" ? "SCRCPY_BIN" : "ADB"],
           FileManager.default.isExecutableFile(atPath: configured) { return URL(fileURLWithPath: configured) }
        #endif
        let bundled = runtimeDirectory.appendingPathComponent(name)
        return FileManager.default.isExecutableFile(atPath: bundled.path) ? bundled : nil
    }

    nonisolated private static func capture(_ executable: URL, arguments: [String]) -> (status: Int32, output: String) {
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
                        Button { showPreferences = true } label: { Label("Preferences", systemImage: "slider.horizontal.3") }
                            .buttonStyle(.bordered)
                        Spacer()
                        Button { model.isRunning ? model.stop() : model.start() } label: {
                            Label(model.isRunning ? "Stop mirroring" : "Start mirroring", systemImage: model.isRunning ? "stop.fill" : "play.fill").frame(minWidth: 145)
                        }
                        .buttonStyle(.borderedProminent)
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
            Image(systemName: "rectangle.on.rectangle").font(.system(size: 20, weight: .semibold)).foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text("SGRGPY").font(.system(size: 16, weight: .bold, design: .rounded))
                Text("gui the f outta scrcpy").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if model.isRefreshing { ProgressView().controlSize(.small) }
            Button { model.refreshDevices() } label: { Label("Refresh devices", systemImage: "arrow.clockwise") }
                .buttonStyle(.bordered).disabled(model.isRefreshing)
        }
        .padding(.horizontal, 22).padding(.vertical, 16).background(.bar)
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(model.mirrorMode ? "Device mirror" : "Extended display", systemImage: model.mirrorMode ? "iphone" : "macbook.and.iphone").font(.headline)
                Spacer()
                Circle().fill(model.isRunning ? Color.green : Color.secondary.opacity(0.5)).frame(width: 8, height: 8)
                Text(model.isRunning ? "Running" : "Not started").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "iphone.gen3").font(.system(size: 74, weight: .ultraLight)).foregroundStyle(.secondary.opacity(0.55))
            Text(model.selectedSerial.isEmpty ? "Select an Android device to begin" : model.selectedSerial).font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
            Text("The live video is displayed in scrcpy’s native window.").font(.caption).foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 380).padding(20)
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
        Button { model.sendNavigation(key) } label: { Label(title, systemImage: icon).frame(maxWidth: .infinity, minHeight: 38) }
            .buttonStyle(.bordered).disabled(model.selectedSerial.isEmpty).help("Send Android \(title) key")
    }

    private var devicePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DEVICE").font(.caption2.weight(.bold)).foregroundStyle(.secondary)
            Picker("Android device", selection: $model.selectedSerial) {
                Text("Choose a device…").tag("")
                ForEach(model.devices) { device in Text(device.serial).tag(device.serial) }
            }
            .labelsHidden().disabled(model.devices.isEmpty)
            if model.devices.isEmpty { Text("Enable USB debugging, accept the prompt, then refresh.").font(.caption).foregroundStyle(.secondary) }
        }
        .padding(14).background(cardBackground)
    }

    private var parameterCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Stream quality").font(.headline)
            parameter("Resolution", value: $model.resolution, range: 240...2160, step: 30, suffix: "px")
            parameter("Bitrate", value: $model.bitrate, range: 1_000_000...40_000_000, step: 1_000_000, suffix: "bps")
            parameter("Frame rate", value: $model.fps, range: 15...120, step: 1, suffix: "fps")
        }
        .padding(14).background(cardBackground)
    }

    private func parameter(_ title: String, value: Binding<Int>, range: ClosedRange<Int>, step: Int, suffix: String) -> some View {
        VStack(spacing: 5) {
            HStack {
                Text(title).font(.subheadline)
                Spacer()
                TextField(title, value: value, format: .number.grouping(.never)).frame(width: 88).multilineTextAlignment(.trailing).textFieldStyle(.roundedBorder)
                Text(suffix).font(.caption).foregroundStyle(.secondary).frame(width: 34, alignment: .leading)
            }
            Slider(value: Binding(get: { Double(value.wrappedValue) }, set: { value.wrappedValue = Int($0.rounded()) }), in: Double(range.lowerBound)...Double(range.upperBound), step: Double(step)).tint(Color.accentColor)
        }
    }

    private var optionsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Options").font(.headline)
            Toggle("Mirror device screen", isOn: $model.mirrorMode)
            Toggle("Audio", isOn: $model.audioEnabled)
            Toggle("Show touches", isOn: $model.showTouches)
            Toggle("Keep device awake", isOn: $model.stayAwake)
            Toggle("Record session", isOn: $model.record)
        }
        .toggleStyle(.switch).padding(14).background(cardBackground)
    }

    private var statusBar: some View {
        HStack(spacing: 8) {
            Image(systemName: model.isRunning ? "circle.fill" : "info.circle").foregroundStyle(model.isRunning ? .green : .secondary)
            Text(model.status).lineLimit(1)
            Spacer()
            Text("Bundled scrcpy 5.0.1").foregroundStyle(.tertiary)
        }
        .font(.caption).padding(.horizontal, 22).padding(.vertical, 10).background(.bar)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 14).fill(Color(nsColor: .controlBackgroundColor))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.secondary.opacity(0.12)))
    }
}

struct PreferencesView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var profileName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Preferences").font(.title2.bold())
                    Text("Appearance, recording destination, and presets.").font(.subheadline).foregroundStyle(.secondary)
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
                    Text("Recording files are MKV. This setting does not affect ADB pull.").font(.caption).foregroundStyle(.secondary)
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
                            Button(role: .destructive) { model.profiles.removeAll { $0.id == profile.id } } label: { Image(systemName: "trash") }
                                .help("Delete preset")
                        }
                    }
                    HStack {
                        TextField("Preset name", text: $profileName)
                        Button { model.saveProfile(name: profileName); profileName = "" } label: { Label("Save current", systemImage: "plus") }
                            .disabled(profileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .formStyle(.grouped)
        }
        .padding(22).frame(width: 560, height: 560)
    }
}
