# foundryup.ps1 - The installer for Foundry.
$BASE_DIR=$env:LOCALAPPDATA
$FOUNDRY_DIR="$BASE_DIR\foundry"
$FOUNDRY_VERSIONS_DIR="$FOUNDRY_DIR\versions"
$FOUNDRY_BIN_DIR="$FOUNDRY_DIR\bin"

$FOUNDRYUP_JOBS = ""

$BINS="forge","cast","anvil","chisel"

$env:RUSTFLAGS="${RUSTFLAGS:--C target-cpu=native}"

$CURRENTDIR = (Get-Item .).FullName

function List {
    if (Test-Path -Path $FOUNDRY_VERSIONS_DIR) {
        foreach ($VERSION in Get-ChildItem -Path $FOUNDRY_VERSIONS_DIR) {
            say $VERSION
            foreach ($bin in $BINS) {
                $bin_path="$VERSION\$bin"
                say "- $("$bin_path --version" | Invoke-Expression)"
            }
        }
    }else {
        foreach ($bin in $BINS) {
            $bin_path="$FOUNDRY_BIN_DIR\$bin"
            say "- $(ensure $bin --version)"
        }
    }
    Exit 0
}

function Use() {
    if ($FOUNDRYUP_VERSION -eq "") {
        err "no version provided"
    }
    $FOUNDRY_VERSION_DIR="$FOUNDRY_VERSIONS_DIR\$FOUNDRYUP_VERSION"
    if (Test-Path $FOUNDRY_VERSION_DIR) {
        foreach ($bin in $BINS) {
            $bin_path="$FOUNDRY_BIN_DIR\$bin.exe"
            Copy-Item "$FOUNDRY_VERSION_DIR\$bin.exe" $bin_path -Force
            # Print usage msg
            Say "use - $(Invoke-Expression "$bin_path --version")"
        } 
    }
    exit 0
  else
    err "version $FOUNDRYUP_VERSION not installed"
}

function Say {
    param (
        [string]$text,
        [int]$out
    )
    if ($out -eq 0) {
        Write-Host "foundryup: $text"
    }
    elseif ($out -eq 1) {
        Write-Warning "foundryup: $text"
    }else {
        Write-Host "foundryup: $text" -ForegroundColor Red
    }
}

function Warn {
    param (
        [string]$text
    )  
    say "warning: $text" 1}

function Err {
    param (
        [string]$text
    )
    say "$text" 2
    Exit 1
}

function To_Lower {
    param (
        [string]$text
    )
  Write-Host $text.ToLower()
}

function Need_CMD {
    param (
        [string]$cmd
    )
    if (!(Check_CMD $cmd)) {
        Err "need $cmd (command not found)"
        Exit
    }
}

function Check_CMD {
    param (
        [string]$cmd
    )
    try {
        if (Invoke-Expression $cmd) {
            return $true
        }
    }
    catch {
        return $false
    }
}

# Run a command that should never fail. If the command fails execution
# will immediately terminate with an error showing the failing command.
function Ensure {
    $cmd = $args[0]
    foreach ($arg in $args[1..$args.Length]) {
        $cmd += " $arg"
    }
    if (Invoke-Expression $cmd) {
        Err "command failed: $($cmd)"
    }
}

# Downloads $1 into $2 or stdout
function Download {
    param (
        [string]$url,
        [string]$output
    )
    Invoke-WebRequest -Uri $url -OutFile $output
}

function Usage {
    Write-Host "
The installer for Foundry.

Update or revert to a specific Foundry version with ease.

By default, the latest stable version is installed from built binaries.

USAGE:
    foundryup <OPTIONS>

OPTIONS:
    -h, --help      Print help information
    -i, --install   Install a specific version from built binaries
    -l, --list      List versions installed from built binaries
    -u, --use       Use a specific installed version from built binaries
    -b, --branch    Build and install a specific branch
    -P, --pr        Build and install a specific Pull Request
    -C, --commit    Build and install a specific commit
    -r, --repo      Build and install from a remote GitHub repo (uses default branch if no other options are set)
    -p, --path      Build and install a local repository
    -j, --jobs      Number of CPUs to use for building Foundry (default: all CPUs)
    --arch          Install a specific architecture (supports amd64 and arm64)
    --platform      Install a specific platform (supports win32, linux, and darwin)
    "
}

# Banner Function for Foundry
function Banner {
    Write-Host "

.xOx.xOx.xOx.xOx.xOx.xOx.xOx.xOx.xOx.xOx.xOx.xOx.xOx.xOx.xOx.xOx.xOx.xOx
╔═╗ ╔═╗ ╦ ╦ ╔╗╔ ╔╦╗ ╦═╗ ╦ ╦         Portable and modular toolkit
╠╣  ║ ║ ║ ║ ║║║  ║║ ╠╦╝ ╚╦╝    for Ethereum Application Development
╚   ╚═╝ ╚═╝ ╝╚╝ ═╩╝ ╩╚═  ╩                 written in Rust.
.xOx.xOx.xOx.xOx.xOx.xOx.xOx.xOx.xOx.xOx.xOx.xOx.xOx.xOx.xOx.xOx.xOx.xOx

Repo       : https://github.com/foundry-rs/foundry
Book       : https://book.getfoundry.sh/
Chat       : https://t.me/foundry_rs/
Support    : https://t.me/foundry_support/
Contribute : https://github.com/foundry-rs/foundry/blob/master/CONTRIBUTING.md

.xOx.xOx.xOx.xOx.xOx.xOx.xOx.xOx.xOx.xOx.xOx.xOx.xOx.xOx.xOx.xOx.xOx.xOx

"
}

function Main {
    Need_CMD git

    $FOUNDRYUP_REPO=""
    $FOUNDRYUP_BRANCH=""
    $FOUNDRYUP_VERSION=""
    $FOUNDRYUP_LOCAL_REPO=""
    $FOUNDRYUP_PR=""
    $FOUNDRYUP_COMMIT=""
    $FOUNDRYUP_ARCH="" 
    #$FOUNDRYUP_PLATFORM=""

    if ($args -ne "") {
        $params = $args -split " "
        while ($params.Count -gt 0) {
            switch ($params[0]) {
                '--' { $params = $params[1..$params.Length]; break}
        
                {$_ -in '-r', '--repo'} { $FOUNDRYUP_REPO = $params[1]; $params = $params[2..$params.Length] }
                {$_ -in '-b', '--branch'} { $FOUNDRYUP_BRANCH = $params[1]; $params = $params[2..$params.Length] }
                {$_ -in '-i', '--install'} { $FOUNDRYUP_VERSION = $params[1]; $params = $params[2..$params.Length] }
                {$_ -in '-l', '--list'} { List; $params = $params[1..$params.Length] }
                {$_ -in '-u', '--use'} { $FOUNDRYUP_VERSION = $params[1]; Use; $params = $params[2..$params.Length] }
                {$_ -in '-p', '--path'} { $FOUNDRYUP_LOCAL_REPO = $params[1]; $params = $params[2..$params.Length] }
                '--pr' { $FOUNDRYUP_PR = $params[1]; $params = $params[2..$params.Length] }
                {$_ -in '-c', '--commit'} { $FOUNDRYUP_COMMIT = $params[1]; $params = $params[2..$params.Length] }
                {$_ -in '-j', '--jobs'} { $FOUNDRYUP_JOBS = [int]$params[1]; $params = $params[2..$params.Length] }
                '--arch' { $FOUNDRYUP_ARCH = $params[1]; $params = $params[2..$params.Length] }
                #'--platform' { $FOUNDRYUP_PLATFORM = $params[1]; $params = $params[2..$params.Length] }
                {$_ -in '-h', '--help'} {
                    usage
                    exit 0
                }
                default {
                    warn "unknown option: $($params[0])"
                    usage
                    exit 1
                }
            }
        }
    }
    
    [array]$CARGO_BUILD_ARGS="--release"
    if ($FOUNDRYUP_JOBS) {
        $CARGO_BUILD_ARGS += "--jobs $FOUNDRYUP_JOBS"
    }
    
    # Print the banner after successfully parsing args
    Banner

    if ($FOUNDRYUP_PR -ne "") {
        if ($FOUNDRYUP_BRANCH -eq "") {
            $FOUNDRYUP_BRANCH="refs/pull/$FOUNDRYUP_PR/head"
        }else {
            Err "can't use --pr and --branch at the same time"
        }
    }

    # Installs foundry from a local repository if --path parameter is provided
    if ($FOUNDRYUP_LOCAL_REPO -ne "") {
        Need_CMD cargo
    
        # Ignore branches/versions as we do not want to modify local git state
        if ($FOUNDRYUP_REPO -or $FOUNDRYUP_BRANCH -or $FOUNDRYUP_VERSION) {
            Warn "--branch, --version, and --repo arguments are ignored during local install"
        }
        
        # Enter local repo and build
        Say "installing from $FOUNDRYUP_LOCAL_REPO"
        Set-Location $FOUNDRYUP_LOCAL_REPO
        Ensure cargo build --bins $CARGO_BUILD_ARGS

        foreach ($bin in $BINS) {
            # Copy binaries to the foundry bin directory
            Copy-Item -Path "$FOUNDRYUP_LOCAL_REPO\target\release\$bin.exe" -Destination "$FOUNDRY_BIN_DIR\$bin" -Force
        }
        Say "done"
        Set-Location -Path $CURRENTDIR
        exit 0
    }

    if ($FOUNDRYUP_REPO -eq "") {
        $FOUNDRYUP_REPO="foundry-rs/foundry"
    }
       
    # Install by downloading binaries
    if ( $FOUNDRYUP_REPO -eq "foundry-rs/foundry" -and $FOUNDRYUP_BRANCH -eq "" -and $FOUNDRYUP_COMMIT -eq "") {
        if ($FOUNDRYUP_VERSION -eq "") {
            $FOUNDRYUP_VERSION="stable"
        }
        $FOUNDRYUP_TAG=$FOUNDRYUP_VERSION

        # Normalize versions (handle channels, versions without v prefix
        if ($FOUNDRYUP_VERSION -match "^nightly") {
            $FOUNDRYUP_VERSION="nightly"
        }elseif ($FOUNDRYUP_VERSION -match "(\d+\.\d+\.\d+)") {
            # Add v prefix
            $FOUNDRYUP_VERSION="v$FOUNDRYUP_VERSION"
            $FOUNDRYUP_TAG="$FOUNDRYUP_VERSION"
        }

        Say "installing foundry (version $FOUNDRYUP_VERSION, tag $FOUNDRYUP_TAG)"

        $EXT = "zip"
        $PLATFORM = "win32"

        if ($FOUNDRYUP_ARCH -eq "") {
            $ARCHITECTURE = ($env:PROCESSOR_ARCHITECTURE.ToLower())
        }else {
            if ($FOUNDRYUP_ARCH -ne "amd64") {
                Err "unsupported architecture: $FOUNDRYUP_ARCH"
                Err "Try, building from Source."
            }
        }

        # Compute the URL of the release tarball in the Foundry repository.
        $RELEASE_URL="https://github.com/$FOUNDRYUP_REPO/releases/download/$FOUNDRYUP_TAG/"
        $BIN_ARCHIVE_URL="${RELEASE_URL}foundry_${FOUNDRYUP_VERSION}_${PLATFORM}_${ARCHITECTURE}.$EXT"
        #MAN_TARBALL_URL="${RELEASE_URL}foundry_man_${FOUNDRYUP_VERSION}.tar.gz"

        New-Item -Path $FOUNDRY_VERSIONS_DIR -ItemType Directory -ErrorAction SilentlyContinue
        # Download and extract the binaries archive
        Say "downloading forge, cast, anvil, and chisel for $FOUNDRYUP_TAG version"
        $tmp="$FOUNDRY_DIR\foundry.zip"
        Ensure Download "$BIN_ARCHIVE_URL" "$tmp"
        Expand-Archive -Path $tmp -DestinationPath "$FOUNDRY_VERSIONS_DIR\$FOUNDRYUP_TAG" -Force
        Remove-Item -Path $tmp -Force

        foreach ($bin in $BINS) {
            $bin_path="$FOUNDRY_BIN_DIR\$bin.exe"
            Copy-Item -Path "$FOUNDRY_VERSIONS_DIR\$FOUNDRYUP_TAG\$bin.exe" -Destination $bin_path
            
            # Print installed msg
            Say "installed - $("$bin_path --version" | Invoke-Expression)"
        }
        Say "done"
    }
    # Install by cloning the repo with the provided branch/tag
    else {
        Need_CMD cargo
        
        if ($FOUNDRYUP_BRANCH -eq "") {
            $FOUNDRYUP_BRANCH="master"
        }
        $REPO_PATH="$FOUNDRY_DIR\$FOUNDRYUP_REPO"

        # If repo path does not exist, grab the author from the repo, make a directory in foundry, cd to it and clone.
        if (!(Test-Path $REPO_PATH)) {
            $AUTHOR=$FOUNDRYUP_REPO.split('/')[0]
            Write-Output $AUTHOR
            New-Item -Path "$FOUNDRY_DIR\$AUTHOR" -ItemType Directory
            Set-Location -Path "$FOUNDRY_DIR\$AUTHOR"
            Ensure git clone "https://github.com/$FOUNDRYUP_REPO.git"
        }

        # Force checkout, discarding any local changes
        Set-Location -Path $REPO_PATH
        Ensure git fetch origin "${FOUNDRYUP_BRANCH}:remotes/origin/${FOUNDRYUP_BRANCH}"
        ensure git checkout "origin/${FOUNDRYUP_BRANCH}"

        # If set, checkout specific commit from branch
        if ($FOUNDRYUP_COMMIT -ne "") {
            Say "installing at commit $FOUNDRYUP_COMMIT"
            Ensure git checkout "$FOUNDRYUP_COMMIT"
        }

        # Build the repo and install the binaries locally to the foundry bin directory.
        Ensure "cargo build --bins $CARGO_BUILD_ARGS"
        foreach ($bin in $BINS) {
            $try_path = "$REPO_PATH\target\release\$bin.exe"
            if (Test-Path -Path $try_path) {
                if (Test-Path "$FOUNDRY_BIN_DIR\$bin") {
                    Warn "overwriting existing $bin in $FOUNDRY_BIN_DIR"
                }
                Move-Item -Path $try_path -Destination $FOUNDRY_BIN_DIR -Force
            }
        }           
        Say "done"
        Set-Location -Path $CURRENTDIR
    }
}

Main $args