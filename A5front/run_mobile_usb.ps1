param([string]$DeviceId = 'R3CX30G9Z6M', [switch]$BridgeOnly)
$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot
$bridgePath=Join-Path $PSScriptRoot 'usb_backend_bridge.ps1'
if ($BridgeOnly) { & $bridgePath -DeviceId $DeviceId; return }
# Run the USB bridge independently of Flutter. A debugger exit or USB error cannot stop recovery.
Start-Process powershell -WindowStyle Hidden -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',$bridgePath,'-DeviceId',$DeviceId) | Out-Null
$adbPath=Join-Path $env:LOCALAPPDATA 'Android\sdk\platform-tools\adb.exe'
Write-Host 'Waiting for USB device. Keep the cable connected and approve USB debugging.'
& $adbPath -s $DeviceId wait-for-device
if ($LASTEXITCODE -ne 0) { throw 'USB connection failed.' }
& $adbPath -s $DeviceId reverse tcp:8080 tcp:8080
if ($LASTEXITCODE -ne 0) { throw 'USB port setup failed. The recovery bridge remains running.' }
flutter run -d $DeviceId --dart-define=API_BASE_URL=http://127.0.0.1:8080
Write-Host 'Flutter debugger ended. USB backend recovery remains active independently.'
