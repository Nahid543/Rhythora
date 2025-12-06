Write-Host "🧹 Flutter & Android cleanup started..."

flutter clean

$paths = @(
    "$env:USERPROFILE\.gradle\caches",
    "$env:USERPROFILE\.pub-cache",
    "$env:USERPROFILE\.android\avd",
    "$env:TEMP",
    "$env:LOCALAPPDATA\Temp"
)

foreach ($p in $paths) {
    if (Test-Path $p) {
        Write-Host "Cleaning $p ..."
        Remove-Item "$p\*" -Recurse -Force -ErrorAction SilentlyContinue
    } else {
        Write-Host "$p not found, skipping."
    }
}

Write-Host "✅ Cleanup complete! Free space should increase after a reboot."
