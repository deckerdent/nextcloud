param(
    [switch]$Debug,
    [switch]$DryRun
)

# If user passed our -Debug switch, enable PowerShell debug stream output
if ($Debug) { $DebugPreference = 'Continue' }

function Debug-Log {
    param([string]$Message)
    if ($Debug) { Write-Debug "[DEBUG] $Message" }
}

function Get-GitBash {
    <#
    Returns the path to Git for Windows' bash.exe, or $null if not found.
    #>
    try {
        Debug-Log "Searching for bash.exe via Get-Command"
        $bashCmd = Get-Command bash.exe -ErrorAction SilentlyContinue
        if ($bashCmd) {
            $path = $bashCmd.Source
            Debug-Log "Discovered bash at: $path"
            if ($path -and ($path -match '\\Git\\')) {
                Debug-Log "bash.exe appears to be from Git for Windows; using: $path"
                return $path
            }
            Debug-Log "Found bash.exe is not from Git for Windows; ignoring: $path"
        }

        Debug-Log "Trying to discover Git installation via git.exe"
        $gitCmd = Get-Command git.exe -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($gitCmd) {
            $gitPath = $gitCmd.Path
            if ($gitPath -is [array]) { $gitPath = $gitPath[0] }
            Debug-Log "git.exe found at: $gitPath"
            $gitParent = Split-Path -Parent $gitPath
            $gitRoot = Split-Path -Parent $gitParent
            $candidates = @(
                Join-Path $gitRoot 'bin\\bash.exe'
                Join-Path $gitRoot 'usr\\bin\\bash.exe'
            )
            foreach ($c in $candidates) {
                Debug-Log "Checking candidate: $c"
                if (Test-Path $c) { Write-Host "Git Bash found at $c"; return $c }
            }
        }

        return $null
    }
    catch {
        Write-Error "Get-GitBash error: $($_.Exception.Message)"
        return $null
    }
}

function Get-OpenSSLVersion {
    try {
        if (-not $script:bash) { throw "Git Bash not initialized" }
        $out = & $script:bash -lc "openssl version" 2>&1
        return $out
    }
    catch {
        Write-Error "Get-OpenSSLVersion error: $($_.Exception.Message)"
        throw
    }
}

function Convert-WindowsPathToGitUnix {
    param([Parameter(Mandatory)][string]$WinPath)
    # Convert C:\foo\bar -> /c/foo/bar
    $p = $WinPath -replace '\\', '/'
    $p = $p -replace '^([A-Za-z]):', '/$1'
    if ($p -match '^/([A-Za-z])') {
        $drive = $matches[1].ToLower()
        $p = $p -replace '^/([A-Za-z])', "/$drive"
    }
    return $p
}

function New-FullChainAndKey {
    param(
        [Parameter(Mandatory)][string]$OutPath
    )
    try {
        if (-not $script:bash) { Write-Error "Git Bash not found, please install Git and try again"; exit 1 }
        # /c/Users/... style for mkdir (MSYS2 tool, understands unix paths)
        $unixPath = Convert-WindowsPathToGitUnix -WinPath $OutPath
        # C:/Users/... style for openssl (Windows binary - forward slashes work, no MSYS2 conversion needed)
        $winFwdPath = $OutPath -replace '\\', '/'
        Debug-Log "Creating directory on Git Bash side: $unixPath"

        # MSYS_NO_PATHCONV=1 on openssl prevents /CN=localhost from being converted to a filepath;
        # C:/... paths for -keyout/-out are passed through as-is since they don't start with /
        $cmd = "mkdir -p '$unixPath' && MSYS_NO_PATHCONV=1 openssl req -newkey rsa:2048 -nodes -x509 -days 365 -subj '/CN=localhost' -keyout '$winFwdPath/privkey.pem' -out '$winFwdPath/fullchain.pem'"
        Debug-Log "Running command: $cmd"
        if ($DryRun) { Write-Host "DryRun: $cmd"; return }

        & $script:bash -lc $cmd
        Write-Host "Certificate and key generated at: $OutPath"
    }
    catch {
        Write-Error "New-FullChainAndKey error: $($_.Exception.Message)"
        throw
    }
}

# Initialize script-global bash path and validate
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$repoRootPath = (Resolve-Path -Path (Join-Path $scriptDir '..\..') -ErrorAction Stop).Path
$script:outPath = Join-Path $repoRootPath 'config\swag\config\etc\letsencrypt\live\localhost'
Debug-Log "Resolved scriptDir: $scriptDir, repoRoot: $repoRootPath, outPath: $script:outPath"
$script:bash = Get-GitBash
if (-not $script:bash) {
    Write-Error "Git Bash not found, please install Git and try again"
    exit 1
}

if ($Debug) {
    Get-OpenSSLVersion
}


New-FullChainAndKey -OutPath $script:outPath
