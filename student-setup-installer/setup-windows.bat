@echo off
setlocal
set "BASE=%~dp0"
set "DEST=%LOCALAPPDATA%\Anime Study Tools\Extensions"
if not exist "%DEST%" mkdir "%DEST%"
for %%E in (anime-episode-to-anki immersionkit-full-card-extension) do (if exist "%BASE%payload\%%E" (if exist "%DEST%\%%E" rmdir /s /q "%DEST%\%%E" & xcopy "%BASE%payload\%%E" "%DEST%\%%E\" /E /I /H /Y >nul))
echo %DEST%|clip
start "" "chrome://extensions/"
explorer /select,"%DEST%"
powershell -NoProfile -Command "$y=(Test-NetConnection 127.0.0.1 -Port 19633 -WarningAction SilentlyContinue).TcpTestSucceeded;$a=(Test-NetConnection 127.0.0.1 -Port 8765 -WarningAction SilentlyContinue).TcpTestSucceeded;$p='%BASE%setup.html'.Replace('\','/');$b='file:///'+[uri]::EscapeUriString($p);$d=[uri]::EscapeDataString('%DEST%');$u=$b+'?dest='+$d+'&yomitan='+$(if($y){'ok'}else{'offline'})+'&anki='+$(if($a){'ok'}else{'offline'});Start-Process $u"
endlocal
