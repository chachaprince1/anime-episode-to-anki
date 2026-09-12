$y = Test-NetConnection 127.0.0.1 -Port 19633 -WarningAction SilentlyContinue
$a = Test-NetConnection 127.0.0.1 -Port 8765 -WarningAction SilentlyContinue
Write-Host "Yomitan API (127.0.0.1:19633): $($y.TcpTestSucceeded ? 'OK' : 'OFFLINE')"
Write-Host "AnkiConnect (127.0.0.1:8765): $($a.TcpTestSucceeded ? 'OK' : 'OFFLINE')"
Read-Host 'Press Enter to close'
