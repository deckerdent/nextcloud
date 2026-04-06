param (
    [switch]$Debug,
    [switch]$DryRun
)

$secrets = @{
    "NEXTCLOUD_ADMIN_PASSWORD" = "nextcloud"
    "NEXTCLOUD_DB_PASSWORD"    = "nextcloud"
    "NEXTCLOUD_REDIS_PASSWORD" = "nextcloud"
}

try {
    $envArgs = $Secrets.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }

    if ($Debug) {
        Write-Host "Debug Mode: ON"
        Write-Host "SECRETS Environment Variables to be passed:"
        $envArgs | ForEach-Object { Write-Host $_ }
    }

    if (!$DryRun) {
        Write-Host "Starting Nextcloud stack with Docker Compose..."
        docker compose --env-file .\.env.local up -d $envArgs
    }
    else {
        Write-Host "Dry Run Mode: ON - The following command would be executed:"
        Write-Host "docker compose --env-file .\.env.local up -d $($envArgs -join ' ')"
        return
    }
    
}
catch {
    Write-Error "Failed to start Nextcloud stack: $_"
}