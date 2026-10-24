param([string]$VmHost='192.168.10.14',[Parameter(Mandatory)][string]$KeyFile,[int]$WebPort=5173,[int]$ApiPort=8080,[int]$RemoteApiPort=18080,[int]$RemoteWebPort=18081)
$ErrorActionPreference='Stop'
# Run in a dedicated terminal. Existing ports are never killed automatically.
& ssh.exe -o ExitOnForwardFailure=yes -o ServerAliveInterval=15 -o ServerAliveCountMax=3 -N -i $KeyFile -L "127.0.0.1:${ApiPort}:127.0.0.1:$RemoteApiPort" -L "127.0.0.1:${WebPort}:127.0.0.1:$RemoteWebPort" "root@$VmHost"
if($LASTEXITCODE -ne 0) { throw 'SSH tunnel stopped; inspect SSH error and occupied ports.' }
