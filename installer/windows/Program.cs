using System.Diagnostics;
using System.Net;
using System.Net.Http;
using System.Net.Sockets;
using System.Reflection;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.Win32;

namespace AnimeStudyToolsInstaller;

internal static class Program
{
    [STAThread]
    private static void Main()
    {
        ApplicationConfiguration.Initialize();
        Application.Run(new InstallerForm());
    }
}

internal sealed class InstallerForm : Form
{
    private readonly Label _status = new() { AutoSize = false, Height = 55 };
    private readonly Label _connections = new() { AutoSize = false, Height = 45, ForeColor = Color.DimGray };
    private readonly Button _install = new() { Text = "Install and open Chrome", AutoSize = true };
    private readonly CallbackServer _callback = new();
    private readonly StudyInstaller _installer = new();
    private readonly HashSet<string> _loadedExtensions = new(StringComparer.Ordinal);

    public InstallerForm()
    {
        Text = "Anime Study Tools Installer";
        ClientSize = new Size(700, 510);
        MinimumSize = new Size(650, 460);
        StartPosition = FormStartPosition.CenterScreen;
        var title = new Label { Text = "Install Anime Study Tools", Font = new Font(SystemFonts.DefaultFont.FontFamily, 20, FontStyle.Bold), AutoSize = true };
        var intro = new Label { Text = "This app prepares both extensions and installs the Yomitan helper for your Windows account. Chrome requires one approval for each unpublished extension; everything else is automatic.", AutoSize = false, Height = 44 };
        var steps = new Label { Text = "When Chrome opens:\r\n1. Turn on Developer mode.\r\n2. Click Load unpacked. In Chrome’s folder window, press Ctrl+L, press Ctrl+V, press Enter, then click Select Folder. The correct Anime Episode to Anki path is already copied.\r\n3. Return here and click “Copy ImmersionKit path.” In Chrome, click Load unpacked again and repeat Ctrl+L, Ctrl+V, Enter, Select Folder.\r\n\r\nYou do not need to move, unzip, install Python, or edit any folders.", AutoSize = false, Height = 155 };
        var showImmersion = new Button { Text = "Copy ImmersionKit path", AutoSize = true };
        var check = new Button { Text = "Check connections / repair", AutoSize = true };
        _install.Click += async (_, _) => await InstallAsync();
        showImmersion.Click += (_, _) => _installer.Reveal("immersionkit-full-card-extension");
        check.Click += async (_, _) => await InstallAsync();
        _callback.ExtensionLoaded += extension => BeginInvoke((Action)(() =>
        {
            _loadedExtensions.Add(extension);
            _status.Text = _loadedExtensions.Count == 2
                ? "Chrome loaded both extensions. Setup is complete."
                : $"Chrome loaded {extension}. One Chrome approval remains.";
        }));
        var layout = new FlowLayoutPanel { Dock = DockStyle.Fill, Padding = new Padding(26), FlowDirection = FlowDirection.TopDown, WrapContents = false, AutoScroll = true };
        layout.Controls.AddRange([title, intro, _install, _status, steps, showImmersion, check, _connections]);
        foreach (Control control in layout.Controls) control.Margin = new Padding(0, 0, 0, 13);
        Controls.Add(layout);
        Shown += async (_, _) =>
        {
            if (!_callback.Start(out var warning)) _status.Text = warning;
            await InstallAsync();
        };
    }

    private async Task InstallAsync()
    {
        _install.Enabled = false;
        try
        {
            _installer.Install();
            _status.Text = "The extensions and Yomitan helper are prepared. Chrome is open, and the Anime Episode to Anki folder path is already copied. Complete the two Chrome approval steps below.";
        }
        catch (Exception error) { _status.Text = error.Message; }
        finally { _install.Text = "Repair and reopen Chrome"; _install.Enabled = true; }
        _connections.Text = await _installer.ConnectionSummaryAsync();
    }
}

internal sealed class StudyInstaller
{
    private const string YomitanExtensionId = "likgccmbimhjbgkjambclfkhldnlhbnn";
    private static readonly string[] AnimeFiles = ["background.js", "content.css", "content.js", "core.js", "data-jlpt-n4.csv", "data-jlpt-n5.csv", "installer-probe.js", "jlpt-data.js", "jpdb-connect-background.js", "jpdb-connect.js", "manifest.json", "onboarding.css", "onboarding.html", "onboarding.js"];
    private static readonly string[] ImmersionFiles = ["background-v192.js", "content.css", "content.js", "installer-probe.js", "manifest.json"];
    private readonly string _root = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Anime Study Tools");
    private readonly string _extensionRoot;

    public StudyInstaller() => _extensionRoot = Path.Combine(_root, "Extensions");

    public void Install()
    {
        Directory.CreateDirectory(_extensionRoot);
        ExtractExtension("anime-episode-to-anki", AnimeFiles);
        ExtractExtension("immersionkit-full-card-extension", ImmersionFiles);
        InstallYomitanHost();
        Clipboard.SetText(Path.Combine(_extensionRoot, "anime-episode-to-anki"));
        OpenChromeExtensions();
        Reveal("anime-episode-to-anki");
    }

    private void ExtractExtension(string name, IEnumerable<string> files)
    {
        var destination = Path.Combine(_extensionRoot, name);
        var stage = Path.Combine(_extensionRoot, $".{name}.new-{Guid.NewGuid():N}");
        Directory.CreateDirectory(stage);
        try
        {
            foreach (var file in files) ExtractResource($"payload.extensions.{name}.{file}", Path.Combine(stage, file));
            VerifyManifest(Path.Combine(stage, "manifest.json"));
            if (Directory.Exists(destination)) Directory.Move(destination, Path.Combine(_extensionRoot, $".{name}.backup-{Guid.NewGuid():N}"));
            Directory.Move(stage, destination);
        }
        catch
        {
            if (Directory.Exists(stage)) Directory.Delete(stage, true);
            throw;
        }
    }

    private static void VerifyManifest(string path)
    {
        using var document = JsonDocument.Parse(File.ReadAllBytes(path));
        if (!document.RootElement.TryGetProperty("manifest_version", out var value) || value.GetInt32() != 3)
            throw new InvalidOperationException("An embedded extension manifest is invalid. Download a fresh installer.");
    }

    private void InstallYomitanHost()
    {
        var hostDirectory = Path.Combine(_root, "Yomitan API", "1.0.0");
        Directory.CreateDirectory(hostDirectory);
        var stagedHost = Path.Combine(hostDirectory, $".yomitan-api-host.new-{Guid.NewGuid():N}.exe");
        ExtractResource("resources.yomitan-api-host.exe", stagedHost);
        var hostHash = Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(stagedHost))).ToLowerInvariant()[..12];
        var host = Path.Combine(hostDirectory, $"yomitan-api-host-{hostHash}.exe");
        if (File.Exists(host)) File.Delete(stagedHost); else File.Move(stagedHost, host);
        ExtractResource("helper.yomitan_api.py", Path.Combine(hostDirectory, "yomitan_api.py"));
        ExtractResource("helper.LICENSE.yomitan-api.txt", Path.Combine(hostDirectory, "LICENSE.yomitan-api.txt"));
        var chromeDirectory = Path.Combine(_root, "Chrome Native Host");
        Directory.CreateDirectory(chromeDirectory);
        var nativeManifest = Path.Combine(chromeDirectory, "yomitan_api.json");
        if (File.Exists(nativeManifest)) File.Copy(nativeManifest, nativeManifest + $".backup-{Guid.NewGuid():N}", true);
        var manifest = JsonSerializer.Serialize(new { name = "yomitan_api", description = "Yomitan API native messaging host", path = host, type = "stdio", allowed_origins = new[] { $"chrome-extension://{YomitanExtensionId}/" } }, new JsonSerializerOptions { WriteIndented = true });
        File.WriteAllText(nativeManifest, manifest);
        using var key = Registry.CurrentUser.CreateSubKey(@"Software\Google\Chrome\NativeMessagingHosts\yomitan_api", true);
        key?.SetValue("", nativeManifest, RegistryValueKind.String);
    }

    private static void ExtractResource(string suffix, string path)
    {
        var assembly = Assembly.GetExecutingAssembly();
        var resource = assembly.GetManifestResourceNames().SingleOrDefault(name => name.EndsWith(suffix, StringComparison.Ordinal));
        if (resource is null) throw new InvalidOperationException($"The installer is missing {Path.GetFileName(path)}. Download a fresh copy.");
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        using var input = assembly.GetManifestResourceStream(resource)!;
        using var output = File.Create(path);
        input.CopyTo(output);
    }

    public void Reveal(string extension)
    {
        var path = Path.Combine(_extensionRoot, extension);
        Clipboard.SetText(path);
        Process.Start(new ProcessStartInfo("explorer.exe", $"/select,\"{path}\"") { UseShellExecute = true });
    }

    private static string? ChromePath()
    {
        using var key = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe");
        var registered = key?.GetValue("") as string;
        if (!string.IsNullOrWhiteSpace(registered) && File.Exists(registered)) return registered;
        var candidates = new[] {
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Google", "Chrome", "Application", "chrome.exe"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "Google", "Chrome", "Application", "chrome.exe"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86), "Google", "Chrome", "Application", "chrome.exe")
        };
        return candidates.FirstOrDefault(File.Exists);
    }

    private static void OpenChromeExtensions()
    {
        var chrome = ChromePath() ?? throw new InvalidOperationException("Google Chrome was not found. Install Chrome, then click Repair and reopen Chrome.");
        Process.Start(new ProcessStartInfo(chrome, "chrome://extensions/") { UseShellExecute = true });
    }

    public async Task<string> ConnectionSummaryAsync()
    {
        var yomitan = await PostAsync("http://127.0.0.1:19633/serverVersion", "{}");
        var anki = await PostAsync("http://127.0.0.1:8765", "{\"action\":\"version\",\"version\":6}");
        return $"Yomitan API: {(yomitan ? "ready" : "not ready")}\r\nAnkiConnect: {(anki ? "ready" : "not ready")}";
    }

    private static async Task<bool> PostAsync(string url, string json)
    {
        using var client = new HttpClient { Timeout = TimeSpan.FromSeconds(2) };
        try { return (await client.PostAsync(url, new StringContent(json, Encoding.UTF8, "application/json"))).IsSuccessStatusCode; }
        catch { return false; }
    }
}

internal sealed class CallbackServer
{
    private TcpListener? _listener;
    public event Action<string>? ExtensionLoaded;

    public bool Start(out string warning)
    {
        try
        {
            _listener = new TcpListener(IPAddress.Loopback, 19634); _listener.Start(); _ = AcceptLoop(); warning = string.Empty; return true;
        }
        catch { warning = "Automatic Chrome confirmation is unavailable because port 19634 is already in use. The installation can still finish normally."; return false; }
    }

    private async Task AcceptLoop()
    {
        while (_listener is not null)
        {
            try
            {
                using var client = await _listener.AcceptTcpClientAsync();
                using var stream = client.GetStream();
                var buffer = new byte[8192]; var count = await stream.ReadAsync(buffer);
                var request = Encoding.ASCII.GetString(buffer, 0, count);
                if (request.Contains("/extension-loaded")) ExtensionLoaded?.Invoke(request.Contains("extension=immersionkit") ? "ImmersionKit Full Card Miner" : "Anime Episode to Anki");
                await stream.WriteAsync(Encoding.ASCII.GetBytes("HTTP/1.1 204 No Content\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"));
            }
            catch { return; }
        }
    }
}
