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
    private readonly Label _title = new() { AutoSize = false, Height = 40, Font = new Font(SystemFonts.DefaultFont.FontFamily, 22, FontStyle.Bold) };
    private readonly Label _status = new() { AutoSize = false, Height = 130, Font = new Font(SystemFonts.DefaultFont.FontFamily, 15) };
    private readonly Label _connections = new() { AutoSize = false, Height = 45, ForeColor = Color.DimGray };
    private readonly Button _next = new() { AutoSize = true, Font = new Font(SystemFonts.DefaultFont.FontFamily, 13, FontStyle.Regular), Padding = new Padding(12, 7, 12, 7) };
    private readonly Button _copyAgain = new() { AutoSize = true, Text = "Copy address again", Visible = false, Font = new Font(SystemFonts.DefaultFont.FontFamily, 13, FontStyle.Regular), Padding = new Padding(12, 7, 12, 7) };
    private readonly Button _openChrome = new() { AutoSize = true, Text = "Open Chrome again", Visible = false, Font = new Font(SystemFonts.DefaultFont.FontFamily, 13, FontStyle.Regular), Padding = new Padding(12, 7, 12, 7) };
    private readonly CallbackServer _callback = new();
    private readonly StudyInstaller _installer = new();
    private readonly HashSet<string> _loadedExtensions = new(StringComparer.Ordinal);
    private string _screen = "installing";

    public InstallerForm()
    {
        Text = "Anime Study Tools Installer";
        ClientSize = new Size(670, 430);
        MinimumSize = new Size(600, 380);
        StartPosition = FormStartPosition.CenterScreen;
        _next.Click += async (_, _) => await NextAsync();
        _copyAgain.Click += (_, _) => _installer.CopyPath(_screen == "step3" ? "immersionkit-full-card-extension" : "anime-episode-to-anki");
        _openChrome.Click += (_, _) => OpenRecoveryTarget();
        _callback.ExtensionLoaded += extension => BeginInvoke((Action)(() =>
        {
            _loadedExtensions.Add(extension);
            if (extension.StartsWith("Anime") && _screen == "step2") { _screen = "step3"; _installer.CopyPath("immersionkit-full-card-extension"); Render(); }
            else if (extension.StartsWith("Immersion") && _screen == "step3") { _screen = "checking"; Render(); _ = CheckConnectionsAsync(); }
        }));
        var layout = new FlowLayoutPanel { Dock = DockStyle.Fill, Padding = new Padding(26), FlowDirection = FlowDirection.TopDown, WrapContents = false, AutoScroll = true };
        layout.Controls.AddRange([_title, _status, _next, _copyAgain, _openChrome, _connections]);
        foreach (Control control in layout.Controls) control.Margin = new Padding(0, 0, 0, 13);
        Controls.Add(layout);
        Shown += async (_, _) =>
        {
            if (!_callback.Start(out var warning)) _status.Text = warning;
            Render();
            await InstallAsync();
        };
    }

    private async Task InstallAsync()
    {
        _next.Enabled = false;
        try
        {
            _installer.Install();
            StudyInstaller.OpenChromeExtensions();
            await Task.Delay(500);
            _screen = "step1";
            Render();
            Activate();
            BringToFront();
        }
        catch (Exception error) { _screen = "error"; Render(error.Message); }
        finally { _next.Enabled = true; }
    }

    private void Render(string? error = null)
    {
        var (title, body) = _screen switch {
            "step1" => ("Turn on Developer mode", "Look at the Chrome window. In the upper-right corner, turn on the switch labeled Developer mode."),
            "step2" => ("Add Anime Episode to Anki", "The correct folder address is already copied.\r\n\r\nIn Chrome, click Load unpacked. Press Ctrl-L, Ctrl-V, Enter, then Select Folder."),
            "step3" => ("Add ImmersionKit Full Card Miner", "The correct folder address is already copied.\r\n\r\nIn Chrome, click Load unpacked. Press Ctrl-L, Ctrl-V, Enter, then Select Folder."),
            "checking" => ("Checking your setup", "You do not need to do anything yet."),
            "complete" => ("You’re all set", "Both extensions and the Yomitan helper are installed in the permanent location. You can close this installer."),
            "yomitan" => ("Yomitan needs one setting", "Open Yomitan settings, open Advanced, then enable Yomitan API.\r\n\r\nchrome-extension://likgccmbimhjbgkjambclfkhldnlhbnn/settings.html#general"),
            "anki" => ("Open Anki", "Open Anki Desktop, then return here to check again."),
            "error" => ("Something needs attention", error ?? "Try opening Chrome again."),
            _ => ("Getting everything ready", "This may take a moment. You do not need to do anything yet.")
        };
        _title.Text = title;
        _status.Text = body;
        _next.Text = _screen switch { "step1" => "Next — I turned it on", "step2" or "step3" => "Next — I loaded it", "checking" or "yomitan" or "anki" => "Check again", "complete" => "Finish", "error" => "Try again", _ => "Please wait" };
        _next.Enabled = _screen != "installing";
        _copyAgain.Visible = _screen is "step2" or "step3";
        _openChrome.Text = _screen switch { "yomitan" => "Open Yomitan settings", "anki" => "Open Anki", _ => "Open Chrome again" };
        _openChrome.Visible = _screen is "step1" or "step2" or "step3" or "error" or "yomitan" or "anki";
        _connections.Visible = _screen is "checking" or "yomitan" or "anki";
    }
    private async Task NextAsync()
    {
        if (_screen == "step1") { _screen = _loadedExtensions.Any(value => value.StartsWith("Anime")) ? "step3" : "step2"; _installer.CopyPath(_screen == "step3" ? "immersionkit-full-card-extension" : "anime-episode-to-anki"); }
        else if (_screen == "step2") { _screen = "step3"; _installer.CopyPath("immersionkit-full-card-extension"); }
        else if (_screen == "step3" || _screen == "checking" || _screen == "yomitan" || _screen == "anki") { await CheckConnectionsAsync(); return; }
        else if (_screen == "complete") { Close(); return; }
        else if (_screen == "error") { _screen = "installing"; Render(); await InstallAsync(); return; }
        Render();
    }
    private void OpenRecoveryTarget()
    {
        if (_screen == "yomitan") StudyInstaller.OpenChromeUrl("chrome-extension://likgccmbimhjbgkjambclfkhldnlhbnn/settings.html#general");
        else if (_screen == "anki") Process.Start(new ProcessStartInfo("anki:") { UseShellExecute = true });
        else StudyInstaller.OpenChromeExtensions();
    }
    private async Task CheckConnectionsAsync()
    {
        var summary = await _installer.ConnectionSummaryAsync(); _connections.Text = summary;
        _screen = summary.Contains("Yomitan API: not ready") ? "yomitan" : summary.Contains("AnkiConnect: not ready") ? "anki" : "complete"; Render();
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

    public void CopyPath(string extension)
    {
        var path = Path.Combine(_extensionRoot, extension);
        Clipboard.SetText(path);
        OpenChromeExtensions();
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

    public static void OpenChromeExtensions() => OpenChromeUrl("chrome://extensions/");

    public static void OpenChromeUrl(string url)
    {
        var chrome = ChromePath() ?? throw new InvalidOperationException("Google Chrome was not found. Install Chrome, then click Repair and reopen Chrome.");
        Process.Start(new ProcessStartInfo(chrome, url) { UseShellExecute = true });
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
