[CmdletBinding()]
param(
  [string]$ReleaseTag,

  [string]$InstallRoot = (Join-Path (Join-Path $HOME 'My Coding Projects') 'posh-theme-browser'),

  [switch]$InstallPythonDependencies,

  [switch]$SkipProfileUpdate,

  [switch]$AllowMissingFzf,

  [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$distributionOwner = 'SpillKernelX'
$distributionRepo = 'poshtheme-distribution'
$assetName = 'posh-theme-browser-package.zip'
$rawInstallerUrl = 'https://raw.githubusercontent.com/SpillKernelX/poshtheme-distribution/main/install.ps1'

function Invoke-PtbDistributionWebRequest {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Uri,

    [string]$OutFile
  )

  $requestArguments = @{
    Uri     = $Uri
    Headers = @{
      'User-Agent' = 'poshtheme-distribution-installer'
      'Accept'     = 'application/vnd.github+json'
    }
  }

  if ($OutFile) {
    $requestArguments.OutFile = $OutFile
  }

  if ($PSVersionTable.PSEdition -eq 'Desktop') {
    $requestArguments.UseBasicParsing = $true
  }

  if ($OutFile) {
    Invoke-WebRequest @requestArguments | Out-Null
    return
  }

  return Invoke-RestMethod @requestArguments
}

function Test-PtbManagedInstallRoot {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path
  )

  return (
    (Test-Path (Join-Path $Path 'install.ps1')) -and
    (Test-Path (Join-Path $Path 'posh-theme-tools.ps1')) -and
    (Test-Path (Join-Path $Path 'load-posh-environment.ps1'))
  )
}

$resolvedInstallRoot = [IO.Path]::GetFullPath($InstallRoot)
$installParent = Split-Path -Parent $resolvedInstallRoot
if ($installParent -and -not (Test-Path $installParent)) {
  New-Item -ItemType Directory -Path $installParent -Force | Out-Null
}

$existingEntries = @()
if (Test-Path $resolvedInstallRoot) {
  $existingEntries = @(Get-ChildItem -Path $resolvedInstallRoot -Force -ErrorAction SilentlyContinue)
}

if ((Test-Path (Join-Path $resolvedInstallRoot '.git')) -and -not $Force) {
  throw "Install root '$resolvedInstallRoot' is a git working tree. Pick a different install root or re-run with -Force if you intentionally want to replace it."
}

if ($existingEntries -and -not (Test-PtbManagedInstallRoot -Path $resolvedInstallRoot) -and -not $Force) {
  throw "Install root '$resolvedInstallRoot' already exists and does not look like a managed Posh Theme Browser install. Re-run with -Force only if you want to replace it."
}

$releaseApiUrl = if ($ReleaseTag) {
  'https://api.github.com/repos/{0}/{1}/releases/tags/{2}' -f $distributionOwner, $distributionRepo, $ReleaseTag
} else {
  'https://api.github.com/repos/{0}/{1}/releases/latest' -f $distributionOwner, $distributionRepo
}

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('ptb-distribution-install-' + [guid]::NewGuid().ToString('N'))
$downloadedArchivePath = Join-Path $tempRoot $assetName
$extractRoot = Join-Path $tempRoot 'expanded'
$incomingRoot = Join-Path $installParent ('posh-theme-browser.incoming.' + [guid]::NewGuid().ToString('N'))
$backupRoot = Join-Path $installParent ('posh-theme-browser.backup.' + [guid]::NewGuid().ToString('N'))

try {
  New-Item -ItemType Directory -Path $extractRoot -Force | Out-Null

  $release = Invoke-PtbDistributionWebRequest -Uri $releaseApiUrl
  $asset = @($release.assets | Where-Object { $_.name -eq $assetName } | Select-Object -First 1)[0]
  if (-not $asset) {
    throw "Release asset '$assetName' was not found in the selected release."
  }

  Write-Host ("Downloading {0} from release {1}" -f $assetName, $release.tag_name) -ForegroundColor Cyan
  Invoke-PtbDistributionWebRequest -Uri $asset.browser_download_url -OutFile $downloadedArchivePath

  Expand-Archive -Path $downloadedArchivePath -DestinationPath $extractRoot -Force

  $expandedProjectRoot = if (Test-Path (Join-Path $extractRoot 'install.ps1')) {
    Get-Item -Path $extractRoot
  } else {
    Get-ChildItem -Path $extractRoot -Directory | Select-Object -First 1
  }

  if (-not $expandedProjectRoot) {
    throw 'The downloaded release asset did not contain an installable project folder.'
  }

  $installScript = Join-Path $expandedProjectRoot.FullName 'install.ps1'
  if (-not (Test-Path $installScript)) {
    throw "The downloaded release asset did not contain install.ps1 at $installScript"
  }

  Move-Item -Path $expandedProjectRoot.FullName -Destination $incomingRoot

  if ((Test-Path $resolvedInstallRoot) -and -not $existingEntries) {
    Remove-Item -Path $resolvedInstallRoot -Force -ErrorAction SilentlyContinue
  }

  try {
    if ($existingEntries) {
      Move-Item -Path $resolvedInstallRoot -Destination $backupRoot
    }

    Move-Item -Path $incomingRoot -Destination $resolvedInstallRoot

    if (Test-Path $backupRoot) {
      Remove-Item -Path $backupRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
  } catch {
    if (-not (Test-Path $resolvedInstallRoot) -and (Test-Path $backupRoot)) {
      Move-Item -Path $backupRoot -Destination $resolvedInstallRoot -Force -ErrorAction SilentlyContinue
    }

    throw
  }

  $finalInstallScript = Join-Path $resolvedInstallRoot 'install.ps1'
  & $finalInstallScript `
    -ProjectRoot $resolvedInstallRoot `
    -InstallPythonDependencies:$InstallPythonDependencies `
    -SkipProfileUpdate:$SkipProfileUpdate `
    -AllowMissingFzf:$AllowMissingFzf `
    -InstallMethod archive `
    -UpdateBootstrapUrl $rawInstallerUrl
} finally {
  if (Test-Path $incomingRoot) {
    Remove-Item -Path $incomingRoot -Recurse -Force -ErrorAction SilentlyContinue
  }

  if (Test-Path $tempRoot) {
    Remove-Item -Path $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
  }
}
