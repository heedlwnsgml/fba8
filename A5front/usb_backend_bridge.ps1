param(
    [string]$DeviceId = 'R3CX30G9Z6M',
    [string]$AdbPath = (Join-Path $env:LOCALAPPDATA 'Android\sdk\platform-tools\adb.exe'),
    [string]$LogPath = (Join-Path $PSScriptRoot 'logs\usb-backend-bridge.log'),
    [int]$PollSeconds = 2,
    [int]$MaxChecks = 0
)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $AdbPath)) { throw 'Android SDK adb.exe was not found.' }
$taskMutex = New-Object System.Threading.Mutex($false, ('Local\TravelPlannerUsbBridge_' + ($DeviceId -replace '[^a-zA-Z0-9]', '_')))
$taskOwnsMutex = $false
try {
    try { $taskOwnsMutex = $taskMutex.WaitOne(0) } catch [System.Threading.AbandonedMutexException] { $taskOwnsMutex = $true }
    if (-not $taskOwnsMutex) { Write-Output 'USB backend bridge is already running.'; return }
    $taskLogDirectory = Split-Path -Parent $LogPath
    if ($taskLogDirectory) { New-Item -ItemType Directory -Path $taskLogDirectory -Force | Out-Null }
    function Write-BridgeState([string]$State) {
        if ($script:taskLastState -ne $State) {
            $taskEntry = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + ' ' + $State
            Add-Content -LiteralPath $LogPath -Value $taskEntry -Encoding UTF8
            Write-Output $taskEntry
            $script:taskLastState = $State
        }
    }
    function Invoke-BridgeAdb([string[]]$Arguments) {
        # Native stderr from a disconnected device must not terminate the recovery loop.
        $taskOldPreference = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            $taskOutput = @(& $AdbPath -s $DeviceId @Arguments 2>&1)
            $taskExitCode = $LASTEXITCODE
            return [pscustomobject]@{ ExitCode=$taskExitCode; Text=($taskOutput -join "`n") }
        } finally { $ErrorActionPreference = $taskOldPreference }
    }
    $script:taskLastState = $null
    $taskChecks = 0
    while ($MaxChecks -le 0 -or $taskChecks -lt $MaxChecks) {
        $taskChecks++
        try {
            $taskDevice = Invoke-BridgeAdb -Arguments @('get-state')
            if ($taskDevice.ExitCode -ne 0 -or $taskDevice.Text.Trim() -ne 'device') {
                Write-BridgeState 'USB device unavailable; waiting for reconnect.'
            } else {
                $taskMappings = Invoke-BridgeAdb -Arguments @('reverse','--list')
                if ($taskMappings.ExitCode -eq 0 -and $taskMappings.Text -match '(?m)^\S+\s+tcp:8080\s+tcp:8080\s*$') {
                    Write-BridgeState 'USB backend bridge ready on port 8080.'
                } else {
                    $taskRestore = Invoke-BridgeAdb -Arguments @('reverse','tcp:8080','tcp:8080')
                    if ($taskRestore.ExitCode -eq 0) { Write-BridgeState 'USB backend bridge restored on port 8080.' }
                    else { Write-BridgeState 'USB port restore failed; will retry.' }
                }
            }
        } catch { Write-BridgeState 'USB check failed; recovery loop continues.' }
        if ($MaxChecks -le 0 -or $taskChecks -lt $MaxChecks) { Start-Sleep -Seconds ([Math]::Max(1,$PollSeconds)) }
    }
} finally {
    if ($taskOwnsMutex) { $taskMutex.ReleaseMutex() }
    $taskMutex.Dispose()
}
