param(
    [string]$ProjectPath = (Get-Location).Path
)

$pidFile = Join-Path $ProjectPath ".server.pid"

if (-not (Test-Path $pidFile)) {
    Write-Host "Kein laufender Server registriert."
    exit 0
}

$serverPid = Get-Content $pidFile
$process = Get-Process -Id $serverPid -ErrorAction SilentlyContinue

if ($process) {
    Write-Host "Stoppe Server mit PID $serverPid ..."
    Stop-Process -Id $serverPid -Force
} else {
    Write-Host "Server mit PID $serverPid läuft nicht mehr."
}

Remove-Item $pidFile -ErrorAction SilentlyContinue
Write-Host "Server gestoppt."