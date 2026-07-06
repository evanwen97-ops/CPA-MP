param(
    [string]$CliProxyVersion = "latest",
    [string]$CpaManagerPlusVersion = "latest",
    [switch]$Force
)

$ErrorActionPreference = "Stop"

$BaseDir = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($BaseDir)) {
    $BaseDir = (Get-Location).Path
}

$DownloadsDir = Join-Path $BaseDir ".downloads"
$CliProxyDir = Join-Path $BaseDir "CLIProxyAPI_windows_amd64"
$ManagerDir = Join-Path $BaseDir "cpa-manager-plus_windows_amd64"

function New-RandomToken {
    param([int]$Bytes = 24)
    $buffer = New-Object byte[] $Bytes
    [System.Security.Cryptography.RandomNumberGenerator]::Fill($buffer)
    return [Convert]::ToBase64String($buffer).TrimEnd("=").Replace("+", "-").Replace("/", "_")
}

function Get-ReleaseAsset {
    param(
        [string]$Repository,
        [string]$Version,
        [string]$AssetPattern
    )

    $headers = @{ "User-Agent" = "CPA-setup" }
    if ($Version -eq "latest") {
        $releaseUrl = "https://api.github.com/repos/$Repository/releases/latest"
    } else {
        $releaseUrl = "https://api.github.com/repos/$Repository/releases/tags/$Version"
    }

    Write-Host "Querying $releaseUrl"
    $release = Invoke-RestMethod -Uri $releaseUrl -Headers $headers
    $asset = $release.assets | Where-Object { $_.name -match $AssetPattern } | Select-Object -First 1
    if ($null -eq $asset) {
        throw "Cannot find asset matching '$AssetPattern' in $Repository $($release.tag_name)."
    }

    return [pscustomobject]@{
        TagName = $release.tag_name
        Name = $asset.name
        Url = $asset.browser_download_url
    }
}

function Expand-ReleaseAsset {
    param(
        [string]$Repository,
        [string]$Version,
        [string]$AssetPattern,
        [string]$DestinationDir
    )

    if ((Test-Path -LiteralPath $DestinationDir) -and -not $Force) {
        Write-Host "Using existing $DestinationDir. Pass -Force to re-download."
        return
    }

    New-Item -ItemType Directory -Force -Path $DownloadsDir | Out-Null
    $asset = Get-ReleaseAsset -Repository $Repository -Version $Version -AssetPattern $AssetPattern
    $archivePath = Join-Path $DownloadsDir $asset.Name

    Write-Host "Downloading $($asset.Name) from $Repository $($asset.TagName)"
    Invoke-WebRequest -Uri $asset.Url -OutFile $archivePath -Headers @{ "User-Agent" = "CPA-setup" }

    if (Test-Path -LiteralPath $DestinationDir) {
        Remove-Item -LiteralPath $DestinationDir -Recurse -Force
    }

    $tempDir = Join-Path $DownloadsDir ([System.IO.Path]::GetFileNameWithoutExtension($asset.Name))
    if (Test-Path -LiteralPath $tempDir) {
        Remove-Item -LiteralPath $tempDir -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path $tempDir | Out-Null

    if ($asset.Name.EndsWith(".zip", [System.StringComparison]::OrdinalIgnoreCase)) {
        Expand-Archive -LiteralPath $archivePath -DestinationPath $tempDir -Force
    } elseif ($asset.Name.EndsWith(".tar.gz", [System.StringComparison]::OrdinalIgnoreCase) -or $asset.Name.EndsWith(".tgz", [System.StringComparison]::OrdinalIgnoreCase)) {
        tar -xzf $archivePath -C $tempDir
    } else {
        throw "Unsupported archive format: $($asset.Name)"
    }

    $exe = Get-ChildItem -Path $tempDir -Filter "*.exe" -Recurse | Select-Object -First 1
    if ($null -eq $exe) {
        throw "Downloaded archive does not contain a Windows executable: $($asset.Name)"
    }

    Move-Item -LiteralPath $exe.DirectoryName -Destination $DestinationDir
    Write-Host "Installed to $DestinationDir"
}

function Ensure-CliProxyConfig {
    $configPath = Join-Path $CliProxyDir "config.yaml"
    if ((Test-Path -LiteralPath $configPath) -and -not $Force) {
        Write-Host "Keeping existing CLIProxyAPI config.yaml"
        return
    }

    $apiKey = "sk-" + (New-RandomToken -Bytes 18)
    $managementKey = "cpa-mgmt-" + (New-RandomToken -Bytes 24)
    $authDir = Join-Path $CliProxyDir "auth"
    $escapedAuthDir = $authDir.Replace("\", "\\")

    @"
host: "127.0.0.1"
port: 8317
remote-management:
  allow-remote: false
  secret-key: "$managementKey"
  disable-control-panel: false
  panel-github-repository: "https://github.com/router-for-me/Cli-Proxy-API-Management-Center"
auth-dir: "$escapedAuthDir"
api-keys:
  - "$apiKey"
debug: false
plugins:
  enabled: true
  dir: "plugins"
usage-statistics-enabled: true
redis-usage-queue-retention-seconds: 60
request-retry: 3
max-retry-credentials: 3
ws-auth: true
"@ | Set-Content -LiteralPath $configPath -Encoding UTF8

    @"
CLIProxyAPI API Key: $apiKey
CLIProxyAPI Management Key: $managementKey

Keep this file private. It is ignored by git.
"@ | Set-Content -LiteralPath (Join-Path $BaseDir "LOCAL_CONFIG.generated.txt") -Encoding UTF8

    Write-Host "Generated CLIProxyAPI config.yaml and LOCAL_CONFIG.generated.txt"
}

function Ensure-ManagerConfig {
    $configPath = Join-Path $ManagerDir "config.json"
    if ((Test-Path -LiteralPath $configPath) -and -not $Force) {
        Write-Host "Keeping existing CPA Manager Plus config.json"
        return
    }

    @"
{
  "httpAddr": "127.0.0.1:18317",
  "dataDir": "./data"
}
"@ | Set-Content -LiteralPath $configPath -Encoding UTF8

    Write-Host "Generated CPA Manager Plus config.json"
}

Expand-ReleaseAsset -Repository "router-for-me/CLIProxyAPI" -Version $CliProxyVersion -AssetPattern "windows.*amd64.*\.(zip|tar\.gz|tgz)$" -DestinationDir $CliProxyDir
Expand-ReleaseAsset -Repository "seakee/CPA-Manager-Plus" -Version $CpaManagerPlusVersion -AssetPattern "windows.*amd64.*\.(zip|tar\.gz|tgz)$" -DestinationDir $ManagerDir
Ensure-CliProxyConfig
Ensure-ManagerConfig

Write-Host "Setup complete. Run .\StartCPA.ps1 to start CPA services."
