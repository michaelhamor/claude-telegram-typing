# Install the typing daemon as a Windows Task Scheduler task.
# Starts on login, restarts on failure, runs in background.
#
# Usage: powershell -ExecutionPolicy Bypass -File install.ps1 -Config C:\path\to\config.json

param(
    [Parameter(Mandatory=$true)]
    [string]$Config
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Daemon = Join-Path $ScriptDir "typing-daemon.py"
$TaskName = "ClaudeTypingDaemon"

# Resolve full paths
$Config = (Resolve-Path $Config).Path
if (-not (Test-Path $Daemon)) {
    Write-Error "typing-daemon.py not found in $ScriptDir"
    exit 1
}
if (-not (Test-Path $Config)) {
    Write-Error "Config file not found: $Config"
    exit 1
}

# Find python
$Python = Get-Command python3 -ErrorAction SilentlyContinue
if (-not $Python) {
    $Python = Get-Command python -ErrorAction SilentlyContinue
}
if (-not $Python) {
    Write-Error "Python not found. Install Python 3.8+ and ensure it's on PATH."
    exit 1
}
$PythonPath = $Python.Source

# Validate config
& $PythonPath -c "import json; json.load(open(r'$Config'))" 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Error "Invalid JSON in $Config"
    exit 1
}

# Remove existing task if present
$existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existing) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Host "Removed existing task."
}

# Create the scheduled task
$Action = New-ScheduledTaskAction `
    -Execute $PythonPath `
    -Argument "`"$Daemon`" --config `"$Config`"" `
    -WorkingDirectory $ScriptDir

$Trigger = New-ScheduledTaskTrigger -AtLogOn

$Settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 1) `
    -ExecutionTimeLimit (New-TimeSpan -Days 365) `
    -StartWhenAvailable

$Principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $Action `
    -Trigger $Trigger `
    -Settings $Settings `
    -Principal $Principal `
    -Description "Claude Code Telegram Typing Indicator" | Out-Null

# Start it now
Start-ScheduledTask -TaskName $TaskName

$LogPath = Join-Path $ScriptDir "daemon.log"

Write-Host ""
Write-Host "Typing daemon installed and running."
Write-Host "  Task:      $TaskName (in Task Scheduler)"
Write-Host "  Config:    $Config"
Write-Host "  Logs:      $LogPath"
Write-Host "  Stop:      Stop-ScheduledTask -TaskName $TaskName"
Write-Host "  Uninstall: powershell -File uninstall.ps1"
Write-Host ""
Write-Host "Test by messaging your bot on Telegram."
