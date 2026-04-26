param(
    [switch]$Debug,
    [switch]$DryRun
)

# Enable PowerShell debug stream when -Debug is provided
if ($Debug) { $DebugPreference = 'Continue' }

function Debug-Log {
    param([string]$Message)
    if ($Debug) { Write-Debug "[DEBUG] $Message" }
}

function Copy-ProxyTemplate {
    param(
        [Parameter(Mandatory)][string]$SrcPath,
        [Parameter(Mandatory)][string]$DstPath
    )
    <#
    Copy the template file from $SrcPath to $DstPath. Create parent dir if missing.
    Respects DryRun. Overwrites existing destination by default.
    #>
    try {
        Debug-Log "Copy-ProxyTemplate: src=$SrcPath dst=$DstPath"

        if (-not (Test-Path $SrcPath)) {
            Write-Error "Template not found: $SrcPath"
            exit 1
        }

        $dstDir = Split-Path -Parent $DstPath
        if (-not (Test-Path $dstDir)) {
            if ($DryRun) {
                Write-Host "DryRun: would create directory $dstDir"
            }
            else {
                Debug-Log "Creating directory: $dstDir"
                New-Item -ItemType Directory -Path $dstDir -Force | Out-Null
            }
        }

        if ($DryRun) {
            Write-Host "DryRun: would copy $SrcPath -> $DstPath"
            return
        }

        if (Test-Path $DstPath) {
            Debug-Log "Destination exists and will be overwritten: $DstPath"
        }

        Copy-Item -Path $SrcPath -Destination $DstPath -Force
        Write-Host "Copied $SrcPath to $DstPath"
    }
    catch {
        Write-Error "Unable to copy template: $($_.Exception.Message)"
        exit 1
    }
}

# Main
try {
    $TemplateRelativePath = 'templates/nextcloud.subdomain.conf'
    $DestRelativePath = 'deployment/config/swag/config/nginx/proxy-confs/nextcloud.subdomain.conf'
    Debug-Log "TemplateRelativePath: $TemplateRelativePath"
    Debug-Log "DestRelativePath: $DestRelativePath"

    $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
    $absTemplate = Join-Path $scriptDir $TemplateRelativePath

    # Script is at local-testing/scripts/local/ — three levels up reaches the repo root
    $repoRoot = (Resolve-Path -Path (Join-Path $scriptDir '..\..\..'  ) -ErrorAction Stop).Path
    $absDest = Join-Path $repoRoot $DestRelativePath

    Debug-Log "Absolute template path: $absTemplate"
    Debug-Log "Absolute destination path: $absDest"

    Copy-ProxyTemplate -SrcPath $absTemplate -DstPath $absDest
}
catch {
    Write-Error "Script error: $($_.Exception.Message)"
    exit 1
}
