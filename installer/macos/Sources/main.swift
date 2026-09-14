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
        copyToClipboard(extensionRoot.appendingPathComponent("anime-episode-to-anki").path)
        openChromeExtensions()
        revealAnimeExtension()
        return "The extensions and Yomitan helper are prepared. Chrome is open, and the Anime Episode to Anki folder path is already copied. Complete the two Chrome approval steps below."
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

    func openChromeExtensions() {
        guard let chrome = NSWorkspace.shared.urlForApplication(withBundleIdentifier: chromeBundleID), let url = URL(string: "chrome://extensions/") else { return }
        NSWorkspace.shared.open([url], withApplicationAt: chrome, configuration: NSWorkspace.OpenConfiguration())
    }

    func revealAnimeExtension() {
        let folder = extensionRoot.appendingPathComponent("anime-episode-to-anki", isDirectory: true)
        NSWorkspace.shared.activateFileViewerSelecting([folder])
        copyToClipboard(folder.path)
    }

    func revealImmersionExtension() {
        let folder = extensionRoot.appendingPathComponent("immersionkit-full-card-extension", isDirectory: true)
        NSWorkspace.shared.activateFileViewerSelecting([folder])
        copyToClipboard(folder.path)
    }

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
    private let status = NSTextField(wrappingLabelWithString: "Preparing the installer…")
    private let connection = NSTextField(wrappingLabelWithString: "Yomitan API: checking…\nAnkiConnect: checking…")
    private let button = NSButton(title: "Prepare and open Chrome", target: nil, action: nil)

    convenience init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 680, height: 500), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "Anime Study Tools Installer"
        window.center()
        self.init(window: window)
        buildUI()
    }

    private func buildUI() {
        guard let content = window?.contentView else { return }
        let stack = NSStackView(); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 14; stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 28), stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -28), stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 26), stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -24)])
        let title = NSTextField(labelWithString: "Install Anime Study Tools")
        title.font = .systemFont(ofSize: 24, weight: .bold)
        let explanation = NSTextField(wrappingLabelWithString: "This app prepares both extensions and installs the Yomitan helper for your account. Chrome requires one approval for each unpublished extension; everything else is automatic.")
        explanation.maximumNumberOfLines = 0
        status.maximumNumberOfLines = 0; status.textColor = .secondaryLabelColor
        button.target = self; button.action = #selector(install); button.bezelStyle = .rounded; button.controlSize = .large
        let instructions = NSTextField(wrappingLabelWithString: "When Chrome opens:\n1. Turn on Developer mode.\n2. Click Load unpacked. In Chrome’s folder window, press ⌘⇧G, press ⌘V, press Return, then click Open. The correct Anime Episode to Anki path is already copied.\n3. Return here and click “Copy ImmersionKit path.” In Chrome, click Load unpacked again and repeat ⌘⇧G, ⌘V, Return, Open.\n\nYou do not need to move, unzip, install Python, or edit any folders.")
        instructions.maximumNumberOfLines = 0
        let showImmersion = NSButton(title: "Copy ImmersionKit path", target: self, action: #selector(showImmersionFolder))
        let retry = NSButton(title: "Check connections / repair", target: self, action: #selector(repair))
        connection.maximumNumberOfLines = 0; connection.textColor = .secondaryLabelColor
        stack.addArrangedSubview(title); stack.addArrangedSubview(explanation); stack.addArrangedSubview(button); stack.addArrangedSubview(status); stack.addArrangedSubview(instructions); stack.addArrangedSubview(showImmersion); stack.addArrangedSubview(retry); stack.addArrangedSubview(connection)
        Installer.shared.callbackServer.onLoad = { [weak self] loaded in
            guard let self else { return }
            if Installer.shared.callbackServer.loadedCount == 2 {
                self.status.stringValue = "Chrome loaded both extensions. Setup is complete."
            } else {
                self.status.stringValue = "Chrome loaded \(loaded == "anime" ? "Anime Episode to Anki" : "ImmersionKit Full Card Miner"). One Chrome approval remains."
            }
        }
        if let warning = Installer.shared.callbackServer.start() { status.stringValue = warning }
        install()
    }

    @objc private func install() {
        button.isEnabled = false
        do { status.stringValue = try Installer.shared.install() }
        catch { status.stringValue = error.localizedDescription }
        button.title = "Repair and reopen Chrome"; button.isEnabled = true
        Installer.shared.connectionSummary { [weak self] in self?.connection.stringValue = $0 }
    }

    @objc private func showImmersionFolder() { Installer.shared.revealImmersionExtension() }
    @objc private func repair() { install() }
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
