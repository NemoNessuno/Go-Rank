param(
    [string]$GodotPath = "C:\Users\stitze\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe",
    [string]$ProjectPath = (Get-Location).Path,
    [int]$Port = 7000
)

$pidFile = Join-Path $ProjectPath ".server.pid"
$logFile = Join-Path $ProjectPath ".server.log"

# Alten Server nur anhand der gespeicherten PID beenden
if (Test-Path $pidFile) {
    $oldPid = Get-Content $pidFile -ErrorAction SilentlyContinue

    if ($oldPid) {
        $oldProcess = Get-Process -Id $oldPid -ErrorAction SilentlyContinue

        if ($oldProcess) {
            Write-Host "Stoppe alten Server mit PID $oldPid ..."
            Stop-Process -Id $oldPid -Force
            Start-Sleep -Milliseconds 500
        }
    }

    Remove-Item $pidFile -ErrorAction SilentlyContinue
}

$arguments = @(
    "--path", $ProjectPath,
    "--headless",
    "--",
    "--server"
)

Write-Host "Starte Godot-Server auf Port $Port ..."
Write-Host "Godot: $GodotPath"
Write-Host "Projekt: $ProjectPath"

$process = Start-Process `
    -FilePath $GodotPath `
    -ArgumentList $arguments `
    -WorkingDirectory $ProjectPath

Set-Content -Path $pidFile -Value $process.Id
