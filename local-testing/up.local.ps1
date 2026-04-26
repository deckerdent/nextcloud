param (
    [switch]$Debug,
    [switch]$DryRun,
    [switch]$ReleaseShell
)

$ScriptDir = $PSScriptRoot

if (-not $ScriptDir -or $ScriptDir -eq '') {
    $ScriptDir = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
}

# Repo root is one level up from $ScriptDir (local-testing/)
$repoRoot = (Resolve-Path -Path (Join-Path $ScriptDir '..') -ErrorAction Stop).Path

# Ensure proxy conf and local certs exist; generate if missing
try {
    $proxyConf = Join-Path $repoRoot 'deployment\config\swag\config\nginx\proxy-confs\nextcloud.subdomain.conf'
    if (-not (Test-Path $proxyConf)) {
        Write-Host "Proxy config not found: $proxyConf -- generating with script"
        $genProxy = Join-Path $ScriptDir 'scripts\local\generate-local-nextcloud-subdomain-conf.ps1'
        if (Test-Path $genProxy) {
            $args = @()
            if ($Debug) { $args += '-Debug' }
            if ($DryRun) { $args += '-DryRun' }
            & $genProxy @args
        }
        else {
            Write-Warning "Generator script not found: $genProxy"
        }
    }

    $certsDir = Join-Path $repoRoot 'deployment\config\swag\config\etc\letsencrypt\live\localhost'
    if (-not (Test-Path $certsDir)) {
        Write-Host "Local certs not found: $certsDir -- generating with script"
        $genCerts = Join-Path $ScriptDir 'scripts\local\generate-local-certs.ps1'
        if (Test-Path $genCerts) {
            $args = @()
            if ($Debug) { $args += '-Debug' }
            if ($DryRun) { $args += '-DryRun' }
            & $genCerts @args
        }
        else {
            Write-Warning "Cert generation script not found: $genCerts"
        }
    }
}
catch {
    Write-Warning "Pre-start generation check failed: $($_.Exception.Message)"
}

$EnvPath = Join-Path -Path $ScriptDir -ChildPath ".env.local"
$ComposePath = Join-Path -Path $repoRoot -ChildPath "deployment\docker-compose.yml"

$rs = ''

if ($ReleaseShell) {
    $rs = '-d'
}


$secrets = @{
    "NEXTCLOUD_ADMIN_PASSWORD" = "nextcloud"
    "NEXTCLOUD_DB_PASSWORD"    = "nextcloud"
    "NEXTCLOUD_REDIS_PASSWORD" = "nextcloud"
}

try {
    foreach ($item in $secrets.GetEnumerator()) {
        Write-Host "Setting ***$($item.Key)*** to a secret value..."
        if ($Debug) {
            Write-Host "Debug Mode: ON - Setting ***$($item.Value)*** as the value for ***$($item.Key)***"
        }
        Set-Item "env:$($item.Key)" $item.Value
    }

    if (!$DryRun) {
        Write-Host "Starting Nextcloud stack with Docker Compose..."
        docker compose -f "$ComposePath" --env-file "$EnvPath" up $rs
    }
    else {
        Write-Host "Dry Run Mode: ON - The following command would be executed:"
        Write-Host "***docker compose -f '$ComposePath' --env-file '$EnvPath' up $rs***"
        if ($Debug) {
            Write-Host "Debug Mode: ON - Computed compose is:"
            docker compose -f "$ComposePath" --env-file "$EnvPath" config
            
        }
        return
    }
    
}
catch {
    Write-Error "Failed to start Nextcloud stack: $_"
}
finally {
    foreach ($item in $secrets.GetEnumerator()) {
        Write-Host "Disposing ***$($item.Key)*** from a secret value..."
        if ($Debug) {
            Write-Host "Debug Mode: ON - Disposing ***$($item.Value)*** as the value for ***$($item.Key)***"
        }
        Remove-Item "env:$($item.Key)"
    }
    Write-Host "Script execution completed."
}