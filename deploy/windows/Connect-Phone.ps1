param([Parameter(Mandatory)][string]$Serial,[string]$Adb="$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe",[int]$ApiPort=8080)
$ErrorActionPreference='Stop'
& $Adb -s $Serial get-state
if($LASTEXITCODE -ne 0) { throw 'Connect USB and approve this computer on the phone.' }
& $Adb -s $Serial reverse "tcp:$ApiPort" "tcp:$ApiPort"
if($LASTEXITCODE -ne 0) { throw 'ADB reverse failed' }
& $Adb -s $Serial reverse --list
Write-Host 'Keep the SSH tunnel active. Phone uses http://127.0.0.1:8080.'
