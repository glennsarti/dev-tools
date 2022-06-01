param([Switch]$Install)

$BinRoot = Join-Path $PSScriptRoot 'bin'
  if (-not (Test-Path -Path $BinRoot)) { New-Item -Path $BinRoot -ItemType Directory -Force -Confirm:$false | Out-Null }

if ($Install) {
  $ProfileFile = $PROFILE
  $ProfilePath = Split-Path $ProfileFile -Parent
  if (-not (Test-Path -Path $ProfilePath)) { New-Item -Path $ProfilePath -ItemType Directory -Force -Confirm:$false | Out-Null }

  $PGit = Get-Module -ListAvailable | Where-Object { $_.Name -eq 'posh-git' } | Measure-Object

  if ($PGit.Count -eq 0) {
    Write-Host "Installing Posh-git..."
    Install-Module Posh-Git
  }

  Write-Host "Copying StarShip profile..."
  $StarShipDir = "~/.config"
  $StarShipFile = Join-Path $StarShipDir 'starship.toml'
  if (-not (Test-Path -Path $StarShipDir)) { New-Item -Path $StarShipDir -ItemType Directory -Force -Confirm:$false | Out-Null }
  Copy-Item (Join-Path $PSScriptRoot 'default_starship.toml') $StarShipFile -Force -Confirm:$false | Out-Null

  Function Install-StarShip {
    $ArchName = ""
    $OSName = ""
    $Suffix = ""

    #starship-x86_64-unknown-linux-gnu.tar.gz
    #starship-x86_64-pc-windows-msvc.zip
    #starship-aarch64-apple-darwin.tar.gz

    if ($PSVersionTable.Platform -eq 'Win32NT') {
      $ArchName = 'x86_64'
      $OSName = 'pc-windows'
      $Suffix = ".zip"
    }
    if ($PSVersionTable.Platform -eq 'Unix') {
      if ($PSVersionTable.OS -like '*Darwin*' -and $PSVersionTable.OS -like '*ARM64*') {
        $ArchName = 'aarch64'
        $OSName = 'apple-darwin'
        $Suffix = ".tar.gz"
      } else {
        $ArchName = 'x86_64'
        $OSName = 'unknown-linux'
        $Suffix = ".tar.gz"
      }
    }

    if ($ArchName -eq '' -or $OSname -eq '') {
      Write-Host "Could not determine which Starship package to download for '$($PSVersionTable.OS)'"
      return
    }

    Write-Host "Installing StarShip ($OSName $ArchName)..."
    $Url = 'https://api.github.com/repos/starship/starship/releases/latest'
    $GHRelease = Invoke-RestMethod $Url -Method Get

    # Note - Windows needs latest VCRuntime https://docs.microsoft.com/en-US/cpp/windows/latest-supported-vc-redist?view=msvc-170
    # Get-Command VCRUNTIME140.dll
    $Asset = $GHRelease.assets | Where-Object { $_.name -like "*$ArchName*" -and $_.name -like "*$OSName*"  -and $_.name -like "*$Suffix" } | Select-Object -First 1
    if ($null -eq $Asset) { Write-Host "Could not find a valid asset to download"; return }
    Write-Host "Downloading $($Asset.browser_download_url) ..."
    $TempFile = Join-Path $BinRoot 'starship.download'
    if (Test-Path -Path $TempFile) { Remove-Item $TempFile -Force -Confirm:$false | Out-Null }
    Invoke-WebRequest -Uri $Asset.browser_download_url -Method Get -UseBasicParsing -OutFile $TempFile

    if ($Suffix -eq '.zip') {
      Expand-Archive -Path $TempFile -DestinationPath $BinRoot
    } else {
      & tar -xvf $TempFile '--directory' $BinRoot
    }
  }

  if ( (Test-Path (Join-Path $BinRoot 'starship')) -or (Test-Path (Join-Path $BinRoot 'starship.exe')) ) {
    Write-Host "Starship is already installed"
  } else {
    Install-StarShip
  }

  # MUST BE LAST
  if (Test-Path -Path $ProfileFile) {
    $content = [System.IO.File]::ReadAllText( ( Resolve-Path $ProfileFile ) )
    if ($content -like "*$PSCommandPath*") {
      Write-Host 'This script is already added to the PowerShell Profile'
      return
    }
  }

  Write-Host "Adding this script to the profile..."
  if (-not (Test-Path -Path $ProfileFile)) {
    ". `"$PSCommandPath`"" | Set-Content $ProfileFile -Encoding UTF8 -Force -Confirm:$false
  } else {
    "`n. `"$PSCommandPath`"" | Out-File $ProfileFile -Encoding UTF8 -Append -Force -Confirm:$false
  }

  return
}

If (($null -eq $ENV:ConEmuHWND) -and ($ENV:TERM_PROGRAM -ne 'vscode')) {
  # Import-Module PSConsoleTheme
  # Set-ConsoleTheme 'Bright'

  if ($PSVersionTable.Platform -eq 'Win32NT') {
    Set-Location C:\Source
  } else {
    Set-Location ~/code
  }
}

Function Test-Administrator {
  try {
    $CurrentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $AdministratorRole = [Security.Principal.WindowsBuiltInRole] "Administrator"
    ([Security.Principal.WindowsPrincipal]$CurrentUser).IsInRole($AdministratorRole)
  } catch {
    # TODO: Catch this on non-Windows
    $False
  }
}

# Set ENV for elevated status
If (Test-Administrator) {
  $Env:ISELEVATEDSESSION = 'just needs to be set, never displayed'
}

Import-Module Posh-Git
$ENV:PATH = $ENV:PATH + [IO.Path]::PathSeparator + $PSScriptRoot

# Turn on starship! 🚀🚀🚀
$StarshipExe = Join-Path $BinRoot 'starship'
if ($PSVersionTable.Platform -eq 'Win32NT') { $StarshipExe = $StarshipExe + '.exe' }
Invoke-Expression (& $StarshipExe init powershell)
