import AppKit
import Foundation
import SwiftUI

struct Device: Identifiable, Hashable {
    let serial: String
    let description: String
    var id: String { serial }
}

struct Profile: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var resolution: Int
    var bitrate: Int
    var fps: Int
    var audio: Bool
    var showTouches: Bool
    var stayAwake: Bool
    var extendedDisplay: Bool
}

struct SettingsFile: Codable {
    var appearance = "System"
    var destination = "~/Movies/SGRGPY"
    var resolution = 1080
    var bitrate = 8_000_000
    var fps = 60
    var audio = true
    var showTouches = false
    var stayAwake = true
    var recording = false
    var extendedDisplay = false
    var profiles: [Profile] = []
}

@MainActor
final class AppModel: ObservableObject {
    @Published var devices: [Device] = []
    @Published var selectedSerial = ""
    @Published var status = "Connect an Android device, then refresh."
    @Published var refreshing = false
    @Published var running = false
    @Published var appearance: String { didSet { save() } }
    @Published var destination: String { didSet { save() } }
    @Published var resolution: Int { didSet { save() } }
    @Published var bitrate: Int { didSet { save() } }
    @Published var fps: Int { didSet { save() } }
    @Published var audio: Bool { didSet { save() } }
    @Published var showTouches: Bool { didSet { save() } }
    @Published var stayAwake: Bool { didSet { save() } }
    @Published var recording: Bool { didSet { save() } }
    @Published var extendedDisplay: Bool { didSet { save() } }
    @Published var profiles: [Profile] { didSet { save() } }

    private let settingsURL: URL
    private var scrcpyProcess: Process?
    private var loading = true

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SGRGPY", isDirectory: true)
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        settingsURL = support.appendingPathComponent("settings.json")
        let saved = (try? Data(contentsOf: settingsURL)).flatMap {
            try? JSONDecoder().decode(SettingsFile.self, from: $0)
        } ?? SettingsFile()
        appearance = saved.appearance
        destination = saved.destination
        resolution = saved.resolution
        bitrate = saved.bitrate
        fps = saved.fps
        audio = saved.audio
        showTouches = saved.showTouches
        stayAwake = saved.stayAwake
        recording = saved.recording
        extendedDisplay = saved.extendedDisplay
        profiles = saved.profiles.isEmpty ? Self.defaults : saved.profiles
        loading = false
    }

    private static let defaults = [
        Profile(name: "Balanced", resolution: 1080, bitrate: 8_000_000, fps: 60, audio: true, showTouches: false, stayAwake: true, extendedDisplay: false),
        Profile(name: "Smooth", resolution: 720, bitrate: 4_000_000, fps: 60, audio: true, showTouches: false, stayAwake: true, extendedDisplay: false),
        Profile(name: "High quality", resolution: 1440, bitrate: 16_000_000, fps: 60, audio: true, showTouches: false, stayAwake: true, extendedDisplay: false)
    ]

    private func save() {
        guard !loading else { return }
        let file = SettingsFile(appearance: appearance, destination: destination,
            resolution: resolution, bitrate: bitrate, fps: fps, audio: audio,
            showTouches: showTouches, stayAwake: stayAwake, recording: recording,
            extendedDisplay: extendedDisplay, profiles: profiles)
        guard let data = try? JSONEncoder().encode(file) else { return }
        try? data.write(to: settingsURL, options: .atomic)
    }

    func refreshDevices() {
        guard !refreshing else { return }
        guard let adb = executable("adb") else {
            devices = []
            status = "Bundled ADB unavailable. Rebuild the app bundle or check the install."
            return
        }
        refreshing = true
        status = "Searching for Android devices…"
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = Self.run(adb, ["devices", "-l"])
            DispatchQueue.main.async {
                guard let self else { return }
                self.refreshing = false
                guard result.code == 0 else {
                    self.devices = []
                    self.status = result.output.isEmpty ? "ADB could not list devices." : result.output
                    return
                }
                self.devices = result.output.split(whereSeparator: \.isNewline).compactMap { line in
                    let parts = line.split(whereSeparator: \.isWhitespace).map(String.init)
                    guard parts.count > 1, parts[1] == "device", parts[0] != "List" else { return nil }
                    return Device(serial: parts[0], description: String(line))
                }
                if !self.devices.contains(where: { $0.serial == self.selectedSerial }) { self.selectedSerial = "" }
                if self.devices.count == 1 { self.selectedSerial = self.devices[0].serial }
                self.status = self.devices.isEmpty
                    ? "No authorized devices. Enable USB debugging and accept the prompt on your phone."
                    : "\(self.devices.count) device(s) ready."
            }
        }
    }

    func start() {
        guard !running else { return }
        guard !selectedSerial.isEmpty else { status = "Select a connected device first."; return }
        guard let scrcpy = executable("scrcpy"), let adb = executable("adb"), let server = resource("scrcpy-server") else {
            status = "Bundled scrcpy runtime is incomplete. Download a release build of SGRGPY again."
            return
        }
        let folder = (destination as NSString).expandingTildeInPath
        if recording {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: folder, isDirectory: &isDirectory), isDirectory.boolValue else {
                status = "Recording destination does not exist. Choose or create a folder in Preferences."
                return
            }
        }

        let task = Process()
        task.executableURL = scrcpy
        task.arguments = arguments()
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        var env = ProcessInfo.processInfo.environment
        env["ADB"] = adb.path
        env["SCRCPY_SERVER_PATH"] = server.path
        if let icons = Bundle.main.resourceURL?.appendingPathComponent("runtime") { env["SCRCPY_ICON_DIR"] = icons.path }
        let extraPaths = [scrcpy.deletingLastPathComponent().path, adb.deletingLastPathComponent().path]
        env["PATH"] = (extraPaths + (env["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin").components(separatedBy: ":"))
            .reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }.joined(separator: ":")
        task.environment = env
        task.terminationHandler = { [weak self] child in
            DispatchQueue.main.async {
                guard let self else { return }
                self.running = false
                self.scrcpyProcess = nil
                self.status = child.terminationStatus == 0 ? "scrcpy session ended." : "scrcpy exited with code \(child.terminationStatus)."
            }
        }
        do {
            try task.run()
            scrcpyProcess = task
            running = true
            status = "Mirroring \(selectedSerial) in scrcpy’s video window."
        } catch { status = "Could not launch scrcpy: \(error.localizedDescription)" }
    }

    func stop() {
        guard let child = scrcpyProcess, child.isRunning else { return }
        child.terminate()
        status = "Stopping scrcpy…"
    }

    func navigate(_ key: String) {
        guard !selectedSerial.isEmpty, let adb = executable("adb") else { status = "Select a device first."; return }
        let serial = selectedSerial
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = Self.run(adb, ["-s", serial, "shell", "input", "keyevent", key])
            DispatchQueue.main.async {
                self?.status = result.code == 0 ? "Navigation command sent." : "ADB navigation failed: \(result.output)"
            }
        }
    }

    func apply(_ profile: Profile) {
        resolution = profile.resolution
        bitrate = profile.bitrate
        fps = profile.fps
        audio = profile.audio
        showTouches = profile.showTouches
        stayAwake = profile.stayAwake
        extendedDisplay = profile.extendedDisplay
    }

    func addProfile(name: String) {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }
        profiles.append(Profile(name: cleanName, resolution: resolution, bitrate: bitrate, fps: fps,
            audio: audio, showTouches: showTouches, stayAwake: stayAwake, extendedDisplay: extendedDisplay))
    }

    private func arguments() -> [String] {
        var args = ["--serial", selectedSerial, "--max-size", String(resolution),
                    "--video-bit-rate", String(bitrate), "--max-fps", String(fps),
                    "--window-title", "SGRGPY — \(selectedSerial)"]
        if !audio { args.append("--no-audio") }
        if showTouches { args.append("--show-touches") }
        if stayAwake { args.append("--stay-awake") }
        if extendedDisplay { args.append("--new-display") }
        if recording {
            let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
            let output = URL(fileURLWithPath: (destination as NSString).expandingTildeInPath).appendingPathComponent("sgrgpy-\(stamp).mkv")
            args += ["--record", output.path]
        }
        return args
    }

    private func resource(_ name: String) -> URL? {
        Bundle.main.resourceURL?.appendingPathComponent("runtime", isDirectory: true).appendingPathComponent(name)
    }

    private func executable(_ name: String) -> URL? {
        if let bundled = resource(name), FileManager.default.isExecutableFile(atPath: bundled.path) { return bundled }
        return nil
    }

    private static func run(_ executable: URL, _ arguments: [String]) -> (code: Int32, output: String) {
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
        } catch { return (-1, error.localizedDescription) }
    }
}

@main
struct SGRGPYApp: App {
    @StateObject private var model = AppModel()
    @State private var preferences = false

    var body: some Scene {
        WindowGroup {
            Dashboard(showPreferences: $preferences)
                .environmentObject(model)
                .preferredColorScheme(model.appearance == "System" ? nil : (model.appearance == "Dark" ? .dark : .light))
                .frame(minWidth: 850, minHeight: 640)
                .task { model.refreshDevices() }
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Preferences…") { preferences = true }.keyboardShortcut(",", modifiers: [.command])
            }
        }
    }
}

struct Dashboard: View {
    @EnvironmentObject private var model: AppModel
    @Binding var showPreferences: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            HStack(alignment: .top, spacing: 20) {
                VStack(spacing: 14) { preview; navigation }
                    .frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 14) {
                    devicePicker
                    qualityCard
                    optionsCard
                    HStack {
                        Button { showPreferences = true } label: { Label("Preferences", systemImage: "slider.horizontal.3") }
                            .buttonStyle(.bordered)
                        Spacer()
                        Button { model.running ? model.stop() : model.start() } label: {
                            Label(model.running ? "Stop" : "Start mirroring", systemImage: model.running ? "stop.fill" : "play.fill")
                                .frame(minWidth: 145)
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
            Image(systemName: "rectangle.on.rectangle").font(.title2).foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text("SGRGPY").font(.system(size: 16, weight: .bold, design: .rounded))
                Text("gui the f outta scrcpy").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if model.refreshing { ProgressView().controlSize(.small) }
            Button { model.refreshDevices() } label: { Label("Refresh devices", systemImage: "arrow.clockwise") }
                .buttonStyle(.bordered).disabled(model.refreshing)
        }
        .padding(.horizontal, 22).padding(.vertical, 16).background(.bar)
    }

    private var preview: some View {
        VStack(spacing: 14) {
            HStack {
                Label(model.extendedDisplay ? "Extended display" : "Device mirror", systemImage: "iphone")
                    .font(.headline)
                Spacer()
                Circle().fill(model.running ? Color.green : Color.secondary.opacity(0.5)).frame(width: 8, height: 8)
                Text(model.running ? "Running" : "Ready").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "iphone.gen3").font(.system(size: 76, weight: .ultraLight)).foregroundStyle(.secondary.opacity(0.55))
            Text(model.selectedSerial.isEmpty ? "Choose a connected Android device" : model.selectedSerial)
                .font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
            Text("The live video is shown in scrcpy’s own native window.")
                .font(.caption).foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 370).padding(20)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.secondary.opacity(0.15)))
    }

    private var navigation: some View {
        HStack(spacing: 12) {
            nav("Recent", "square.stack.3d.up", "KEYCODE_APP_SWITCH")
            nav("Home", "house", "KEYCODE_HOME")
            nav("Back", "chevron.left", "KEYCODE_BACK")
        }
    }

    private func nav(_ title: String, _ icon: String, _ key: String) -> some View {
        Button { model.navigate(key) } label: { Label(title, systemImage: icon).frame(maxWidth: .infinity, minHeight: 38) }
            .buttonStyle(.bordered).disabled(model.selectedSerial.isEmpty)
            .help("Send Android \(title) key using ADB")
    }

    private var devicePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ANDROID DEVICE").font(.caption2.weight(.bold)).foregroundStyle(.secondary)
            Picker("Android device", selection: $model.selectedSerial) {
                Text("Choose a device…").tag("")
                ForEach(model.devices) { Text($0.serial).tag($0.serial) }
            }.labelsHidden().disabled(model.devices.isEmpty)
            if model.devices.isEmpty { Text("Enable USB debugging, authorize this Mac, then refresh.").font(.caption).foregroundStyle(.secondary) }
        }.padding(14).background(card)
    }

    private var qualityCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Stream quality").font(.headline)
            quality("Resolution", $model.resolution, 240...2160, 30, "px")
            quality("Bitrate", $model.bitrate, 1_000_000...40_000_000, 1_000_000, "bps")
            quality("Frame rate", $model.fps, 15...120, 1, "fps")
            Toggle("Extended display", isOn: $model.extendedDisplay)
        }.padding(14).background(card)
    }

    private func quality(_ title: String, _ value: Binding<Int>, _ range: ClosedRange<Int>, _ step: Int, _ unit: String) -> some View {
        VStack(spacing: 5) {
            HStack {
                Text(title).font(.subheadline)
                Spacer()
                TextField(title, value: value, format: .number.grouping(.never))
                    .frame(width: 88).multilineTextAlignment(.trailing).textFieldStyle(.roundedBorder)
                Text(unit).font(.caption).foregroundStyle(.secondary).frame(width: 35, alignment: .leading)
            }
            Slider(value: Binding(get: { Double(value.wrappedValue) }, set: { value.wrappedValue = Int($0.rounded()) }), in: Double(range.lowerBound)...Double(range.upperBound), step: Double(step))
        }
    }

    private var optionsCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Options").font(.headline)
            Toggle("Audio", isOn: $model.audio)
            Toggle("Show touches", isOn: $model.showTouches)
            Toggle("Keep device awake", isOn: $model.stayAwake)
            Toggle("Record session", isOn: $model.recording)
        }.padding(14).background(card)
    }

    private var statusBar: some View {
        HStack(spacing: 8) {
            Image(systemName: model.running ? "circle.fill" : "info.circle")
                .foregroundStyle(model.running ? .green : .secondary)
            Text(model.status).lineLimit(1)
            Spacer()
            Text("Bundled scrcpy runtime").foregroundStyle(.tertiary)
        }.font(.caption).padding(.horizontal, 22).padding(.vertical, 10).background(.bar)
    }

    private var card: some View {
        RoundedRectangle(cornerRadius: 14).fill(Color(nsColor: .controlBackgroundColor))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.secondary.opacity(0.12)))
    }
}

struct PreferencesView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var profileName = ""
    @State private var profileError = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Preferences").font(.title2.bold())
                    Text("Appearance, recordings and reusable profiles.").font(.subheadline).foregroundStyle(.secondary)
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
                    }.pickerStyle(.segmented)
                }
                Section("Recording destination") {
                    HStack {
                        TextField("~/Movies/SGRGPY", text: $model.destination)
                        Button("Choose…") {
                            let panel = NSOpenPanel()
                            panel.canChooseFiles = false
                            panel.canChooseDirectories = true
                            panel.allowsMultipleSelection = false
                            panel.begin { if $0 == .OK, let url = panel.url { model.destination = url.path } }
                        }
                    }
                    Text("Recording output location only; the bundled scrcpy server and ADB are included in this app.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Profiles") {
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
                            }.help("Delete preset")
                        }
                    }
                    HStack {
                        TextField("Preset name", text: $profileName)
                        Button("Save preset") {
                            model.addProfile(name: profileName)
                            if profileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { profileError = "Enter a name for the preset." }
                            else { profileName = ""; profileError = "" }
                        }
                    }
                    if !profileError.isEmpty { Text(profileError).foregroundStyle(.red).font(.caption) }
                }
            }.formStyle(.grouped)
        }.padding(22).frame(width: 560, height: 580)
    }
}
