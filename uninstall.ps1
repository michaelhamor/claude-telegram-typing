# Uninstall the typing daemon Task Scheduler task.
#
# Usage: powershell -ExecutionPolicy Bypass -File uninstall.ps1

$TaskName = "ClaudeTypingDaemon"

$existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existing) {
    Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Host "Task '$TaskName' removed."
} else {
    Write-Host "No task found."
}
