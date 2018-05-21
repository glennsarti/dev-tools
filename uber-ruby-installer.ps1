param()

$ErrorActionPreference = 'Stop'

$is64bit = ([System.IntPtr]::Size -eq 8)

if (-not $is64bit) {
  Throw "Script not supported on 32bit operating systems"; return
}

# Workaround for https://github.com/majkinetor/au/issues/142
[System.Net.ServicePointManager]::SecurityProtocol = 3072 -bor
  768 -bor
  [System.Net.SecurityProtocolType]::Tls -bor
  [System.Net.SecurityProtocolType]::Ssl3

$rubyList = @(
  '2.1.9', '2.1.9 (x64)',
  '2.4.3-2 (x86)', '2.4.3-2 (x64)'
)
$devKit2_64 = 'C:\tools\DevKit2-x64'
$devKit2_32 = 'C:\tools\DevKit2'
$msys_64 = 'C:\tools\msys64'
$msys_32 = 'C:\tools\msys32'

function Get-UruTag($rubyVersion) {
  $bareRubyVersion = ($rubyVersion -split ' ')[0]

  if ($rubyVersion -match 'x64') {
    Write-Output "$($bareRubyVersion)-x64"
  } else {
    Write-Output "$($bareRubyVersion)-x86"
  }
}

Function Get-DestDir($rubyVersion) {
  Write-Output ("C:\tools\ruby" + $rubyVersion.Replace(' ','').Replace('(','').Replace(')',''))
}

# Instal chocolatey if it isn't already here...
$ChocoExists = $false
try {
  Get-Command 'choco.exe' | Out-Null
  $ChocoExists = $true
} catch {
  $ChocoExists = $false
}
If (-not $ChocoExists) {
  Write-Host "Installing Chocolatey..."
  Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
} else { Write-Host "Chocolatey is installed" -ForegroundColor Green}

# 7Zip command line
$7zExists = $false
try {
  Get-Command '7z.exe' | Out-Null
  $7zExists = $true
} catch {
  $7zExists = $false
}
If (-not $7zExists) {
  Write-Host "Installing 7Zip command line..."
  & choco install 7zip.commandline -y
} else { Write-Host "7Zip is installed" -ForegroundColor Green}

# URU
if (-not (Test-Path -Path "$($ENV:ChocolateyInstall)\bin\uru.ps1")) {
  Write-Host "Installing URU..."
  Write-Host "Determining the current version of URU..."
  $uruver = (Invoke-WebRequest 'https://bitbucket.org/jonforums/uru/downloads/uru.json' -UseBasicParsing | ConvertFrom-JSON).version
  $downloadURL = "https://bitbucket.org/jonforums/uru/downloads/uru.${uruver}.nupkg"
  $uruRoot = 'C:\Tools'
  $uruInstall = Join-Path -Path $uruRoot -ChildPath 'URUInstall'
  $uruInstallNuget = Join-Path -Path $uruInstall -ChildPath 'uru.0.8.5.nupkg'
  if (Test-Path -Path $uruInstall) { Remove-Item -Path $uruInstall -Force -Recurse -Confirm:$false | Out-Null }
  New-Item -Path $uruInstall -ItemType Directory | Out-Null
  Write-Host "Downloading URU installer..."
  (New-Object System.Net.WebClient).DownloadFile($downloadURL, $uruInstallNuget)

  Write-Host "Running the URU installer..."
  choco install uru -source $uruInstall -f -y

  # Cleaning up...
  if (Test-Path -Path $uruInstall) { Remove-Item -Path $uruInstall -Force -Recurse -Confirm:$false | Out-Null }
} else { Write-Host "Uru is installed" -ForegroundColor Green}

# Prompt the user for which ruby versions to install
$itemsToInstall = @()
do {
  Write-Host ""
  Write-Host ""
  Write-Host "A. Install all versions ('$($rubyList -join "', '")')"
  For($index = 0; $index -lt $rubyList.Count; $index++) {
    Write-Host "$([char]($index + 66)). Install '$($rubyList[$index])'"
  }
  Write-Host "----"
  Write-Host "Z. Install custom version"
  Write-Host ""
  $misc = (Read-Host "Select an option").ToUpper()
} until ( ($misc -ge 'A') -and $misc -le 'Z')

$option = ([int][char]$misc - 65)
switch ($option) {
  0 {
    $itemsToInstall = $rubyList
    break;
  }
  25 {
    # Ask the user for the version string
    do {
      $misc = ''
      Write-Host ""
      Write-Host "Note, the version must match one on the Ruby Installer archive website"
      Write-Host "  https://rubyinstaller.org/downloads/archives/"
      $misc = (Read-Host "Enter Ruby version to install (e.g. '2.4.3-2 (x64)')")
    } until ($misc -ne '')
    $itemsToInstall = @($misc)
  }
  default {
    $itemsToInstall = @($rubyList[$option - 1])
  }
}

if ( ($itemsToInstall -join '') -eq '' ) { Throw "Nothing to install!!"; return; }

# Now we have the names of the rubies, time to install!
$itemsToInstall | % {
  $rubyVersionString = $_
  Write-Host "Installing Ruby ${rubyVersionString} ..."

  $rubyIs64 = $rubyVersionString -match 'x64'
  $rubyVersionString -match '^([\d.-]+)' | Out-Null
  $rubyVersion = $matches[1]

  $rubyURL = $null
  $32bitDevKit = $false
  $64bitDevKit = $false
  $RIDKDevKit = $false
  $destDir = Get-DestDir($rubyVersionString)
  $uruTag = Get-UruTag($rubyVersionString)

  # URL base page
  # https://rubyinstaller.org/downloads/archives/
  switch -Regex ($rubyVersion) {
    '^2\.[0123]\.' {
      # Example URL
      # 32bit 'https://dl.bintray.com/oneclick/rubyinstaller/ruby-2.3.3-i386-mingw32.7z'
      # 64bit 'https://dl.bintray.com/oneclick/rubyinstaller/ruby-2.3.3-x64-mingw32.7z'
      if ($rubyIs64) {
        $rubyURL = "https://dl.bintray.com/oneclick/rubyinstaller/ruby-${rubyVersion}-x64-mingw32.7z"
        $64bitDevKit = $true
      } else {
        $rubyURL = "https://dl.bintray.com/oneclick/rubyinstaller/ruby-${rubyVersion}-i386-mingw32.7z"
        $32bitDevKit = $true
      }
    }
    '^2\.4\.1\-' {
      # Example URL
      # 2.4.1 only
      # 32bit 'https://github.com/oneclick/rubyinstaller2/releases/download/2.4.1-2/rubyinstaller-2.4.1-2-x86.7z'
      # 64bit 'https://github.com/oneclick/rubyinstaller2/releases/download/2.4.1-2/rubyinstaller-2.4.1-2-x64.7z'
      if ($rubyIs64) {
        $rubyURL = "https://github.com/oneclick/rubyinstaller2/releases/download/${rubyVersion}/rubyinstaller-${rubyVersion}-x64.7z"
      } else {
        $rubyURL = "https://github.com/oneclick/rubyinstaller2/releases/download/${rubyVersion}/rubyinstaller-${rubyVersion}-x86.7z"
      }
      $RIDKDevKit = $true
    }

    '^2\.[56789]\.|^2\.4\.[23456789]-' {
      # Example URL
      # 2.4.2+ and 2.5+ only
      # 32bit 'https://github.com/oneclick/rubyinstaller2/releases/download/rubyinstaller-2.5.1-1/rubyinstaller-2.5.1-1-x86.7z'
      # 64bit 'https://github.com/oneclick/rubyinstaller2/releases/download/rubyinstaller-2.5.1-1/rubyinstaller-2.5.1-1-x64.7z'
      if ($rubyIs64) {
        $rubyURL = "https://github.com/oneclick/rubyinstaller2/releases/download/rubyinstaller-${rubyVersion}/rubyinstaller-${rubyVersion}-x64.7z"
      } else {
        $rubyURL = "https://github.com/oneclick/rubyinstaller2/releases/download/rubyinstaller-${rubyVersion}/rubyinstaller-${rubyVersion}-x86.7z"
      }
      $RIDKDevKit = $true
    }
    default { Throw "Unknown Ruby Version $rubyVersion"; return }
  }

  # Install the ruby files
  if (-not (Test-Path -Path $destDir)) {
    $tempFile = Join-Path -path $ENV:Temp -ChildPath 'rubydl.7z'
    $tempExtract = Join-Path -path $ENV:Temp -ChildPath ('rubydl_extracted' + [guid]::NewGuid().ToString())
    if (Test-Path -Path $tempExtract) { Start-Sleep -Seconds 2; Remove-Item -Path $tempExtract -Recurse -Confirm:$false -Force | Out-Null }

    Write-Host "Downloading from $rubyURL ..."
    if (Test-Path -Path $tempFile) { Start-Sleep -Seconds 2; Remove-Item -Path $tempFile -Confirm:$false -Force | Out-Null }
    Invoke-WebRequest -URI $rubyURL -OutFile $tempFile -UseBasicParsing

    & 7z x $tempFile "`"-o$tempExtract`"" -y

    # Get the root directory from the extract
    $misc = (Get-ChildItem -Path $tempExtract | ? { $_.PSIsContainer } | Select -First 1).Fullname

    Write-Host "Install ruby to $destDir ..."
    if (Test-Path -Path $destDir) { Remove-Item -Path $destDir -Recurse -Confirm:$false -Force | Out-Null }
    Move-Item -Path $misc -Destination $destDir -Force -Confirm:$false | Out-Null

    Write-Host "Adding to URU..."
    & uru admin add "$($destDir)\bin" --tag $uruTag

    Write-Host "Cleaning up..."
    if (Test-Path -Path $tempFile) { Remove-Item -Path $tempFile -Confirm:$false -Force | Out-Null }
    if (Test-Path -Path $tempExtract) { Remove-Item -Path $tempExtract -Recurse -Confirm:$false -Force | Out-Null }
  } else { Write-Host "Ruby ${rubyVersionString} is already installed to $destDir"}

  # Configure the ruby installation
  & uru $uruTag
  Write-Output "Ruby version..."
  & ruby -v
  Write-Output "Gem version..."
  & gem -v

  # Update the system gems
  $tempRC =  Join-Path -path $ENV:Temp -ChildPath 'gem.rc'
@"
---
:backtrace: false
:bulk_threshold: 1000
:sources:
- http://rubygems.org
:update_sources: true
:verbose: true
"@ | Set-Content -Encoding Ascii -Path $tempRC -Force -Confirm:$false

  Write-Host "Updating system gems (via HTTP)..."
  if ($rubyVersion -match '^1\.') {
    & gem update --system --no-rdoc --config-file $tempRC
  } else {
    & gem update --system --no-rdoc --no-document --config-file $tempRC
  }
  Remove-Item -Path $tempRC -Force -Confirm:$false | Out-Null

  # Install bundler if it's not already there
  $BundleExists = $false
  try {
    Get-Command 'bundle' | Out-Null
    $BundleExists = $true
  } catch {
    $BundleExists = $false
  }
  if (-not $BundleExists) {
    Write-Host "Installing bundler..."
    if ($rubyVersion -match '^1\.') {
      & gem install bundler --no-ri --no-rdoc
    } else {
      & gem install bundler --no-ri --no-rdoc --no-document --force
    }
  } else { Write-Host "Bundler already installed" -ForegroundColor Green }

  # MSYS2 dev kit (Ruby 2.4+)
  if ($RIDKDevKit) {
    if ($rubyIs64) {
      # DevKit for Ruby 2.4+ 64bit
      if (-not (Test-Path -Path $msys_64)) {
        Write-Host "Installing DevKit 2.4+ x64"
        Start-Process -FilePath 'choco' -ArgumentList (@('install','msys2','-y','--params','/NoUpdate')) -NoNewWindow -Wait | Out-Null
      } else { Write-Host "DevKit 2.4+ 64bit is installed" -ForegroundColor Green }
    } else {
      # DevKit for Ruby 2.4+ 32bit
      if (-not (Test-Path -Path $msys_32)) {
        Write-Host "Installing DevKit 2.4+ x86"
        Start-Process -FilePath 'choco' -ArgumentList (@('install','msys2','-y','-x86','-f','--params','/NoUpdate')) -NoNewWindow -Wait | Out-Null
      } else { Write-Host "DevKit 2.4+ 32bit is installed" -ForegroundColor Green }
    }

    & ridk install 2 3
  }

  # 64 and 32 bit legacy DevKit
  if ($64bitDevKit -or $32bitDevKit) {
    #******************
    # ORDER IS VERY IMPORTANT - 64bit Devkit MUST be installed before 32bit
    #******************
    # DevKit for Ruby 2.x 64bit
    if ($is64bit -and (-not (Test-Path -Path $devKit2_64))) {
      Write-Host "Installing DevKit 2.x x64. NOTE - Errors are expected"
      Start-Process -FilePath 'choco' -ArgumentList (@('install','ruby2.devkit','-y')) -NoNewWindow -Wait | Out-Null
      if (-not (Test-Path -Path $devKit2_32)) { Throw "DevKit 2.x x64 did not install" }
      Move-Item $devKit2_32 $devKit2_64 -Force -EA Stop
    } else { Write-Host "DevKit 2.x 64bit is installed" -ForegroundColor Green }

    # DevKit for Ruby 2.x 32bit
    if (-not (Test-Path -Path $devKit2_32)) {
      Write-Host "Installing DevKit 2.x x86. NOTE - Errors are expected"
      Start-Process -FilePath 'choco' -ArgumentList (@('install','ruby2.devkit','-y','-x86','-f')) -NoNewWindow -Wait | Out-Null
      if (-not (Test-Path -Path $devKit2_32)) { Throw "DevKit 2.x x86 did not install" }
    } else { Write-Host "DevKit 2.x 32bit is installed" -ForegroundColor Green }

    # 64bit legacy devkit
    if ($64bitDevKit) {
@"
---
- $( $destDir -replace '\\','/' )
"@ | Set-Content -Path "$($devKit2_64)\config.yml"
      Push-Location $devKit2_64
      Write-Host "Installing DevKit $devKit2_64 for $rubyVersion"
      & ruby dk.rb install
      Pop-Location
    }

  # 32bit legacy devkit
    if ($32bitDevKit) {
@"
---
- $( $destDir -replace '\\','/' )
"@ | Set-Content -Path "$($devKit2_32)\config.yml"
      Push-Location $devKit2_32
      Write-Host "Installing DevKit $devKit2_32 for $rubyVersion"
      & ruby dk.rb install
      Pop-Location
    }
  }
}

Write-Host "Cleanup URU assignment"
& uru nil

Write-Host "Available ruby list" -ForegroundColor Green
Write-Host "-------------------" -ForegroundColor Green
& uru list
