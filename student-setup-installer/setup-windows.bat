@echo off
setlocal EnableExtensions
set "BASE=%~dp0"
set "DEST=%LOCALAPPDATA%\Anime Study Tools\Extensions"
set "SETUP_BASE=%BASE%"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop';foreach($e in 'anime-episode-to-anki','immersionkit-full-card-extension'){Get-Content -Raw (Join-Path $env:SETUP_BASE ('payload\'+$e+'\manifest.json'))|ConvertFrom-Json|Out-Null}" || goto :badpayload
if not exist "%DEST%" mkdir "%DEST%" || goto :copyfail
for %%E in (anime-episode-to-anki immersionkit-full-card-extension) do (
  if exist "%DEST%\.%%E.new" rmdir /s /q "%DEST%\.%%E.new"
  robocopy "%BASE%payload\%%E" "%DEST%\.%%E.new" /E /COPY:DAT /R:1 /W:1 >nul
  if errorlevel 8 goto :copyfail
  if exist "%DEST%\.%%E.backup" rmdir /s /q "%DEST%\.%%E.backup"
  if exist "%DEST%\%%E" ren "%DEST%\%%E" ".%%E.backup" >nul
  ren "%DEST%\.%%E.new" "%%E" || goto :copyfail
)
reg query "HKCU\Software\Google\Chrome\NativeMessagingHosts\yomitan_api" >nul 2>nul
if errorlevel 1 start "Yomitan API helper" /wait cmd /c ""%DEST%\anime-episode-to-anki\install-yomitan-api-windows.bat""
explorer /select,"%DEST%\anime-episode-to-anki"
echo %DEST%\anime-episode-to-anki|clip
set "SETUP_DEST=%DEST%"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop';$chrome=$null;foreach($root in @($env:ProgramFiles,${env:ProgramFiles(x86)},$env:LOCALAPPDATA)){if($root){$candidate=Join-Path $root 'Google\Chrome\Application\chrome.exe';if(Test-Path -LiteralPath $candidate){$chrome=$candidate;break}}};if(-not $chrome){throw 'Google Chrome was not found. Install Chrome, then run this launcher again.'};$y=$false;$a=$false;try{$null=Invoke-RestMethod 'http://127.0.0.1:19633/serverVersion' -Method Post -Body '{}' -ContentType 'application/json' -TimeoutSec 2;$y=$true}catch{};try{$body=@{action='version';version=6}|ConvertTo-Json;$null=Invoke-RestMethod 'http://127.0.0.1:8765' -Method Post -ContentType 'application/json' -Body $body -TimeoutSec 2;$a=$true}catch{};$p=$env:SETUP_BASE+'setup.html';$b='file:///'+[uri]::EscapeUriString($p.Replace('\','/'));$d=[uri]::EscapeDataString($env:SETUP_DEST);$u=$b+'?dest='+$d+'&yomitan='+$(if($y){'ok'}else{'offline'})+'&anki='+$(if($a){'ok'}else{'offline'});Start-Process -FilePath $chrome -ArgumentList 'chrome://extensions/';Start-Process -FilePath $chrome -ArgumentList $u" || goto :chromeerror
endlocal
exit /b 0
:badpayload
echo A required extension manifest is missing or invalid. Download a fresh installer.
pause
exit /b 1
:copyfail
echo Could not stage the extensions. Existing copies were left as backups where possible.
pause
exit /b 1
:chromeerror
echo Google Chrome could not be opened. Install Chrome, then run this launcher again.
pause
exit /b 1
