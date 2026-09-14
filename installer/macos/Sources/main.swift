import AppKit
import Foundation
import Network

private let chromeBundleID = "com.google.Chrome"
private let yomitanExtensionID = "likgccmbimhjbgkjambclfkhldnlhbnn"

final class CallbackServer {
    private var listener: NWListener?
    private(set) var loaded = Set<String>()
    var loadedCount: Int { loaded.count }
    var onLoad: ((String) -> Void)?

    func start() -> String? {
        do {
            let server = try NWListener(using: .tcp, on: 19634)
            server.newConnectionHandler = { [weak self] connection in
                connection.start(queue: .main)
                connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { data, _, _, _ in
                    let request = String(data: data ?? Data(), encoding: .utf8) ?? ""
                    let component = request.contains("extension=immersionkit") ? "immersionkit" : "anime"
                    if request.contains("/extension-loaded") {
                        self?.loaded.insert(component)
                        self?.onLoad?(component)
                    }
                    let response = "HTTP/1.1 204 No Content\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
                    connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in connection.cancel() })
                }
            }
            server.start(queue: .main)
            listener = server
            return nil
        } catch {
            return "Automatic Chrome confirmation is unavailable because port 19634 is already in use. The installation can still finish normally."
        }
    }
}

final class Installer {
    static let shared = Installer()
    let callbackServer = CallbackServer()
    let fileManager = FileManager.default
    let root: URL
    let extensionRoot: URL
    let hostRoot: URL
    let nativeManifest: URL

    private init() {
        let library = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first!
        root = library.appendingPathComponent("Application Support/Anime Study Tools", isDirectory: true)
        extensionRoot = root.appendingPathComponent("Extensions", isDirectory: true)
        hostRoot = root.appendingPathComponent("Yomitan API/1.0.0", isDirectory: true)
        nativeManifest = library.appendingPathComponent("Application Support/Google/Chrome/NativeMessagingHosts/yomitan_api.json")
    }

    func install() throws -> String {
        guard let resourceRoot = Bundle.main.resourceURL?.appendingPathComponent("payload/extensions", isDirectory: true) else {
            throw NSError(domain: "AnimeStudyTools", code: 1, userInfo: [NSLocalizedDescriptionKey: "The installer payload is missing. Download a fresh copy."])
        }
        try fileManager.createDirectory(at: extensionRoot, withIntermediateDirectories: true)
        for name in ["anime-episode-to-anki", "immersionkit-full-card-extension"] {
            let source = resourceRoot.appendingPathComponent(name, isDirectory: true)
            try verifyManifest(in: source)
            let destination = extensionRoot.appendingPathComponent(name, isDirectory: true)
            let stage = extensionRoot.appendingPathComponent(".\(name).new-\(UUID().uuidString)", isDirectory: true)
            try fileManager.copyItem(at: source, to: stage)
            do { try verifyManifest(in: stage) } catch { try? fileManager.removeItem(at: stage); throw error }
            if fileManager.fileExists(atPath: destination.path) {
                let backup = extensionRoot.appendingPathComponent(".\(name).backup-\(UUID().uuidString)", isDirectory: true)
                try fileManager.moveItem(at: destination, to: backup)
            }
            try fileManager.moveItem(at: stage, to: destination)
        }
        try installYomitanHost()
        return ""
    }

    private func verifyManifest(in directory: URL) throws {
        let data = try Data(contentsOf: directory.appendingPathComponent("manifest.json"))
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard object?["manifest_version"] as? Int == 3 else {
            throw NSError(domain: "AnimeStudyTools", code: 2, userInfo: [NSLocalizedDescriptionKey: "An extension payload has an invalid manifest."])
        }
    }

    private func installYomitanHost() throws {
        guard let host = Bundle.main.url(forResource: "yomitan-api-host", withExtension: nil) else {
            throw NSError(domain: "AnimeStudyTools", code: 3, userInfo: [NSLocalizedDescriptionKey: "The bundled Yomitan helper is missing."])
        }
        try fileManager.createDirectory(at: hostRoot, withIntermediateDirectories: true)
        let installedHost = hostRoot.appendingPathComponent("yomitan-api-host")
        let stagedHost = hostRoot.appendingPathComponent(".yomitan-api-host.new-\(UUID().uuidString)")
        try fileManager.copyItem(at: host, to: stagedHost)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: stagedHost.path)
        if fileManager.fileExists(atPath: installedHost.path) { try fileManager.removeItem(at: installedHost) }
        try fileManager.moveItem(at: stagedHost, to: installedHost)
        for resource in ["yomitan_api.py", "LICENSE.yomitan-api.txt"] {
            guard let source = Bundle.main.url(forResource: resource, withExtension: nil) else { continue }
            let destination = hostRoot.appendingPathComponent(resource)
            let stage = hostRoot.appendingPathComponent(".\(resource).new-\(UUID().uuidString)")
            try fileManager.copyItem(at: source, to: stage)
            if fileManager.fileExists(atPath: destination.path) { try fileManager.removeItem(at: destination) }
            try fileManager.moveItem(at: stage, to: destination)
        }

        try fileManager.createDirectory(at: nativeManifest.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fileManager.fileExists(atPath: nativeManifest.path) {
            let backup = nativeManifest.deletingPathExtension().appendingPathExtension("json.backup-\(UUID().uuidString)")
            try? fileManager.copyItem(at: nativeManifest, to: backup)
        }
        let manifest: [String: Any] = [
            "name": "yomitan_api", "description": "Yomitan API native messaging host",
            "path": installedHost.path, "type": "stdio",
            "allowed_origins": ["chrome-extension://\(yomitanExtensionID)/"]
        ]
        let data = try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
        let stagedManifest = nativeManifest.appendingPathExtension("new")
        try data.write(to: stagedManifest, options: .atomic)
        if fileManager.fileExists(atPath: nativeManifest.path) { try fileManager.removeItem(at: nativeManifest) }
        try fileManager.moveItem(at: stagedManifest, to: nativeManifest)
    }

    func openChrome(_ address: String) {
        guard let chrome = NSWorkspace.shared.urlForApplication(withBundleIdentifier: chromeBundleID), let url = URL(string: address) else { return }
        NSWorkspace.shared.open([url], withApplicationAt: chrome, configuration: NSWorkspace.OpenConfiguration())
    }

    func openChromeExtensions() { openChrome("chrome://extensions/") }

    func extensionPath(_ name: String) -> String { extensionRoot.appendingPathComponent(name, isDirectory: true).path }

    func copyToClipboard(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }

    func connectionSummary(completion: @escaping (String) -> Void) {
        let group = DispatchGroup()
        var yomitan = false
        var anki = false
        group.enter(); postJSON("http://127.0.0.1:19633/serverVersion", body: [:]) { yomitan = $0; group.leave() }
        group.enter(); postJSON("http://127.0.0.1:8765", body: ["action": "version", "version": 6]) { anki = $0; group.leave() }
        group.notify(queue: .main) {
            completion("Yomitan API: \(yomitan ? "ready" : "not ready")\nAnkiConnect: \(anki ? "ready" : "not ready")")
        }
    }

    private func postJSON(_ address: String, body: [String: Any], completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: address), let data = try? JSONSerialization.data(withJSONObject: body) else { completion(false); return }
        var request = URLRequest(url: url); request.httpMethod = "POST"; request.httpBody = data
        request.setValue("application/json", forHTTPHeaderField: "Content-Type"); request.timeoutInterval = 2
        URLSession.shared.dataTask(with: request) { data, response, _ in
            completion((response as? HTTPURLResponse)?.statusCode == 200 && data != nil)
        }.resume()
    }
}

final class InstallerWindowController: NSWindowController {
    private var stack = NSStackView()
    private var screen = "installing"
    private var installed = false
    private var callbackWarning: String?

    convenience init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 680, height: 500), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "Anime Study Tools Installer"
        window.center()
        self.init(window: window)
        buildUI()
    }

    private func buildUI() {
        guard let content = window?.contentView else { return }
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 14; stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 28), stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -28), stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 26), stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -24)])
        render()
        Installer.shared.callbackServer.onLoad = { [weak self] loaded in
            guard let self else { return }
            if loaded == "anime" && self.screen == "step2" { self.showImmersionStep() }
            if loaded == "immersionkit" && self.screen == "step3" { self.screen = "checking"; self.render(); self.checkConnections() }
        }
        callbackWarning = Installer.shared.callbackServer.start()
        install()
    }

    @objc private func install() {
        guard !installed else { return }
        do { _ = try Installer.shared.install(); installed = true; screen = "step1"; render(); Installer.shared.openChromeExtensions() }
        catch { screen = "error"; render(error.localizedDescription) }
    }

    private func render(_ error: String? = nil) {
        stack.arrangedSubviews.forEach { stack.removeArrangedSubview($0); $0.removeFromSuperview() }
        let titleText: String; let bodyText: String
        switch screen {
        case "installing": titleText = "Getting everything ready"; bodyText = "This may take a moment. You do not need to do anything yet."
        case "step1": titleText = "Turn on Developer mode"; bodyText = "Look at the Chrome window. In the upper-right corner, turn on the switch labeled Developer mode."
        case "step2": titleText = "Add Anime Episode to Anki"; bodyText = "The correct folder address is already copied.\n\nIn Chrome, click Load unpacked. Press Command-Shift-G, Command-V, Return, then Open."
        case "step3": titleText = "Add ImmersionKit Full Card Miner"; bodyText = "The correct folder address is already copied.\n\nIn Chrome, click Load unpacked. Press Command-Shift-G, Command-V, Return, then Open."
        case "checking": titleText = "Checking your setup"; bodyText = "You do not need to do anything yet."
        case "complete": titleText = "You’re all set"; bodyText = "Both extensions and the Yomitan helper are installed in the permanent location. You can close this installer."
        case "yomitan": titleText = "Yomitan needs one setting"; bodyText = "Open Yomitan settings, open Advanced, then enable Yomitan API.\n\nchrome-extension://likgccmbimhjbgkjambclfkhldnlhbnn/settings.html#general"
        case "anki": titleText = "Open Anki"; bodyText = "Open Anki Desktop, then return here to check again."
        default: titleText = "Something needs attention"; bodyText = error ?? "Try opening Chrome again."
        }
        let title = NSTextField(labelWithString: titleText); title.font = .systemFont(ofSize: 24, weight: .bold)
        let body = NSTextField(wrappingLabelWithString: bodyText); body.maximumNumberOfLines = 0
        stack.addArrangedSubview(title); stack.addArrangedSubview(body)
        if let callbackWarning { let note = NSTextField(wrappingLabelWithString: callbackWarning); note.maximumNumberOfLines = 0; note.textColor = .secondaryLabelColor; stack.addArrangedSubview(note) }
        if screen == "step1" { addButton("Next — I turned it on", #selector(nextStep)); addButton("Open Chrome again", #selector(openChrome)) }
        if screen == "step2" { addButton("Next — I loaded it", #selector(nextStep)); addButton("Copy address again", #selector(copyAnime)); addButton("Open Chrome again", #selector(openChrome)) }
        if screen == "step3" { addButton("Next — I loaded it", #selector(nextStep)); addButton("Copy address again", #selector(copyImmersion)); addButton("Open Chrome again", #selector(openChrome)) }
        if screen == "checking" { addButton("Check again", #selector(checkConnections)) }
        if screen == "complete" { addButton("Repair", #selector(repair)) }
        if screen == "yomitan" { addButton("Open Yomitan settings", #selector(openYomitan)); addButton("Check again", #selector(checkConnections)) }
        if screen == "anki" { addButton("Open Anki", #selector(openAnki)); addButton("Check again", #selector(checkConnections)) }
        if screen == "error" { addButton("Try again", #selector(repair)); addButton("Open Chrome again", #selector(openChrome)) }
    }
    private func addButton(_ title: String, _ action: Selector) { let b = NSButton(title: title, target: self, action: action); b.bezelStyle = .rounded; b.controlSize = .large; stack.addArrangedSubview(b) }
    private func showAnimeStep() { screen = "step2"; Installer.shared.copyToClipboard(Installer.shared.extensionPath("anime-episode-to-anki")); Installer.shared.openChromeExtensions(); render() }
    private func showImmersionStep() { screen = "step3"; Installer.shared.copyToClipboard(Installer.shared.extensionPath("immersionkit-full-card-extension")); Installer.shared.openChromeExtensions(); render() }
    @objc private func nextStep() {
        if screen == "step1" {
            Installer.shared.callbackServer.loaded.contains("anime") ? showImmersionStep() : showAnimeStep()
        } else if screen == "step2" {
            Installer.shared.callbackServer.loaded.contains("immersionkit") ? checkConnections() : showImmersionStep()
        } else if screen == "step3" {
            screen = "checking"; render(); checkConnections()
        }
    }
    @objc private func copyAnime() { Installer.shared.copyToClipboard(Installer.shared.extensionPath("anime-episode-to-anki")); Installer.shared.openChromeExtensions() }
    @objc private func copyImmersion() { Installer.shared.copyToClipboard(Installer.shared.extensionPath("immersionkit-full-card-extension")); Installer.shared.openChromeExtensions() }
    @objc private func openChrome() { Installer.shared.openChromeExtensions() }
    @objc private func openYomitan() { Installer.shared.openChrome("chrome-extension://\(yomitanExtensionID)/settings.html#general") }
    @objc private func openAnki() { NSWorkspace.shared.open(URL(string: "anki:")!) }
    @objc private func repair() { installed = false; screen = "installing"; render(); install() }
    @objc private func checkConnections() { Installer.shared.connectionSummary { [weak self] summary in DispatchQueue.main.async { guard let self else { return }; if summary.contains("Yomitan API: not ready") { self.screen = "yomitan" } else if summary.contains("AnkiConnect: not ready") { self.screen = "anki" } else { self.screen = "complete" }; self.render() } } }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var controller: InstallerWindowController?
    func applicationDidFinishLaunching(_ notification: Notification) {
        controller = InstallerWindowController(); controller?.showWindow(self); NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
