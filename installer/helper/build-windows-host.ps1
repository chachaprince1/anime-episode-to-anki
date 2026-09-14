$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$source = Join-Path $root 'helper\yomitan_api.py'
$expected = 'ade5a1824be628a041249b993a88c29a9efec7de1fad763a590b0995ec55cbfc'
if ((Get-FileHash $source -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expected) { throw 'Pinned Yomitan helper checksum did not match.' }
$venv = Join-Path $env:TEMP ('anime-study-tools-pyinstaller-' + [guid]::NewGuid())
python -m venv $venv
& "$venv\Scripts\python.exe" -m pip install --disable-pip-version-check 'pyinstaller==6.11.1'
$patched = Join-Path $venv 'yomitan_api.py'
$helper = Get-Content $source -Raw
$helper = $helper.Replace('script_path = os.path.realpath(os.path.dirname(__file__))', 'script_path = (os.path.dirname(os.path.abspath(sys.executable)) if getattr(sys, "frozen", False) else os.path.realpath(os.path.dirname(__file__)))')
Set-Content -Path $patched -Value $helper -NoNewline
& "$venv\Scripts\pyinstaller.exe" --noconfirm --clean --onefile --name yomitan-api-host --distpath "$venv\dist" --workpath "$venv\work" --specpath "$venv\spec" $patched
New-Item -ItemType Directory -Force -Path (Join-Path $root 'windows\resources') | Out-Null
Copy-Item "$venv\dist\yomitan-api-host.exe" (Join-Path $root 'windows\resources\yomitan-api-host.exe') -Force
