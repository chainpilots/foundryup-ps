Write-Host "Installing foundryup..."

$BASE_DIR=$env:LOCALAPPDATA
$FOUNDRY_DIR="$BASE_DIR\foundry"
$FOUNDRY_BIN_DIR="$FOUNDRY_DIR\bin"

$BIN_URL="https://raw.githubusercontent.com/chainpilots/foundryup-win/main/foundryup.ps1"
$BIN_PATH="$FOUNDRY_BIN_DIR\foundryup.ps1"

# Create the foundry bin directory and foundryup binary if it doesn't exist.
if (Test-Path $FOUNDRY_DIR) {
    Write-Host "Foundryup already installed."
}else {
    New-Item -ItemType Directory -Path $FOUNDRY_DIR
    New-Item -ItemType Directory -Path $FOUNDRY_BIN_DIR
    Invoke-WebRequest -Uri $BIN_URL -OutFile $BIN_PATH
}
# Only add foundryup if it isn't already in PATH.
$p = [System.Environment]::GetEnvironmentVariables('User')["Path"] -split ';'
if ($p -notcontains $FOUNDRY_BIN_DIR) {
    Write-Host "Adding foundryup to PATH..."
    $p += $FOUNDRY_BIN_DIR
    [System.Environment]::SetEnvironmentVariable('Path', $p -join ';', 'User')
}

Write-Host "Simply run 'foundryup' to install Foundry."