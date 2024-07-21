# Main project directory
$mainProjectDir = Get-Location

# Function to run build_runner commands
function Invoke-BuildRunner {
    param (
        [string]$dir,
        [string]$name
    )
    Write-Host "Processing $name at $dir" -ForegroundColor Cyan
    Set-Location $dir

    Write-Host "Running 'flutter pub get' for $name" -ForegroundColor Green
    flutter pub get

    Write-Host "Running 'dart run build_runner clean' for $name" -ForegroundColor Green
    dart run build_runner clean

    Write-Host "Running 'dart run build_runner build --delete-conflicting-outputs' for $name" -ForegroundColor Green
    dart run build_runner build --delete-conflicting-outputs

    Write-Host "Running 'flutter clean' for $name" -ForegroundColor Green
    flutter clean
}

# Extract submodule paths from .gitmodules
$submodulePaths = git config --file .gitmodules --name-only --get-regexp path | ForEach-Object {
    git config --file .gitmodules --get $_
} | Where-Object { $_ -notmatch "http" }

# Run build_runner for each submodule
foreach ($submodule in $submodulePaths) {
    $submodulePath = Join-Path -Path $mainProjectDir -ChildPath $submodule
    Invoke-BuildRunner $submodulePath "submodule $submodule"
}

# Run build_runner for the main project
Invoke-BuildRunner $mainProjectDir "main project"

# Clean and get dependencies for the main project again
Set-Location $mainProjectDir
Write-Host "Running 'flutter clean' for the main project" -ForegroundColor Yellow
flutter clean
Write-Host "Running 'flutter pub get' for the main project" -ForegroundColor Yellow
flutter pub get
