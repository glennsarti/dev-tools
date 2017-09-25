param()

$ErrorActionPreference = 'Stop'

$is64bit = ([System.IntPtr]::Size -eq 8)

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

# TODO Need to short circuit this if I can...
choco install 7zip.commandline -y

$devKit1x = 'C:\tools\devkit'
$devKit2_64 = 'C:\tools\DevKit2-x64'
$devKit2_32 = 'C:\tools\DevKit2'

Write-Host "Checking for prerequisite packages..."
# Install the various ruby devkits
# Unfortunately devkit installs fail because ruby isn't on the path.
# Just run choco in a different process and ignore the return code.  Use simple file existence checks to see if it failed

# DevKit for Ruby 1.x
if (-not (Test-Path -Path $devKit1x)) {
  Write-Host "Installing DevKit 1.x. NOTE - Errors are expected"
  Start-Process -FilePath 'choco' -ArgumentList (@('install','ruby.devkit','-y')) -NoNewWindow -Wait | Out-Null
  if (-not (Test-Path -Path $devKit1x)) { Throw "DevKit 1.x did not install" }
} else { Write-Host "DevKit 1.x is installed" -ForegroundColor Green }

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

# URU
if (-not (Test-Path -Path "$($ENV:ChocolateyInstall)\bin\uru.ps1")) {
  Write-Output "Installing URU..."
  $downloadURL = 'https://bitbucket.org/jonforums/uru/downloads/uru.0.8.4.nupkg'
  $uruRoot = 'C:\Tools'
  $uruInstall = Join-Path -Path $uruRoot -ChildPath 'URUInstall'
  $uruInstallNuget = Join-Path -Path $uruInstall -ChildPath 'uru.0.8.3.nupkg'
  if (Test-Path -Path $uruInstall) { Remove-Item -Path $uruInstall -Force -Recurse -Confirm:$false | Out-Null }
  New-Item -Path $uruInstall -ItemType Directory | Out-Null
  Write-Output "Downloading URU installer..."
  (New-Object System.Net.WebClient).DownloadFile($downloadURL, $uruInstallNuget)

  Write-Output "Running the URU installer..."
  choco install uru -source $uruInstall -f -y

  # Cleaning up...
  if (Test-Path -Path $uruInstall) { Remove-Item -Path $uruInstall -Force -Recurse -Confirm:$false | Out-Null }
} else { Write-Host "Uru is installed" -ForegroundColor Green}

# Get the list of available ruby versions to install?
# TODO Need a better way to get this.....
$rubyVersions = @{}
Write-Host "Getting list of available current ruby installs ..."
$response = Invoke-WebRequest -Uri 'http://rubyinstaller.org/downloads'
$response.Links | ? { $_.href -match '/ruby-.+-mingw32.7z$'} | % {
  $rubyVersions.Add( ($_.innerHTML -replace 'Ruby ',''), $_.href )
}
Write-Host "Getting list of available older ruby installs ..."
$response = Invoke-WebRequest -Uri 'http://rubyinstaller.org/downloads/archives'
$response.Links | ? { $_.href -match '/ruby-.+-mingw32.7z$'} | % {
  try {
    $rubyVersions.Add( ($_.innerHTML -replace 'Ruby ',''), $_.href )
  } catch {
    # Ignore all errors
  }
}

# Prompt the user for which ruby versions to install
Write-Host ""
Write-Host ""
$itemsToInstall = @{}
do {
  $misc = (Read-Host "Would you like to install a single ruby version or a collection? (S or C)").ToUpper()
} until ( ($misc -eq 'S') -or $misc -eq 'C')
switch ($misc) {
  'S' {
    $orderedList = ($rubyVersions.GetEnumerator() | % { Write-Output $_.Key }| Sort-Object -Descending )
    do {
      Write-Host ""
      Write-Host "Please enter which version to install:"
      Write-Host ""      $index = 1
      $orderedList | % {
        Write-Host "$_"
      }
      Write-Host ""
      $version = Read-Host "Enter selection (e.g. 2.3.1 (x64))"
    } until ( $orderedList -contains $version )
    $itemsToInstall.Add($version,'')
  }
  # Collections are just groups of commonly used ruby versions
  'C' {
    do {
      Write-Host ""
      Write-Host "Please select which collection to install:"
      Write-Host ""
      Write-Host "1. Std. Puppet Collection (2.3.1 (32/64), 2.1.9 (32/64), 2.0.0-x64, 1.9.3)"
      Write-Host ""
      $collection = Read-Host "Enter selection (1-1)"
    } until ( ($collection -eq '1') )
    switch ($collection) {
      '1' { $itemsToInstall = @{
              '2.3.1 (x64)' = '';
              '2.3.1' = '';
              '2.1.9 (x64)' = '';
              '2.1.9' = '';
              '2.0.0-p648 (x64)' = '';
              '1.9.3-p551' = '';
            }
       }
    }      
  }
}

# Now we have the names of the rubies, time to install!
$itemsToInstall.GetEnumerator() | % {
  $rubyVersion = $_.Key
  $rubyURL = $_.Value
  if ($rubyURL -eq '') {
    $rubyURL = $rubyVersions[$rubyVersion]
  }

  Write-Host "Installing Ruby $($rubyVersion) from $($rubyURL)"
  $destDir = Get-DestDir($rubyVersion)

  if (-not (Test-Path -Path $destDir)) {
    $tempFile = Join-Path -path $ENV:Temp -ChildPath 'rubydl.7z'
    $tempExtract = Join-Path -path $ENV:Temp -ChildPath 'rubydl_extracted'
    if (Test-Path -Path $tempExtract) { Start-Sleep -Seconds 2; Remove-Item -Path $tempExtract -Recurse -Confirm:$false -Force | Out-Null }

    Write-Host "Downloading from $rubyURL ..."
    if (Test-Path -Path $tempFile) { Start-Sleep -Seconds 2; Remove-Item -Path $tempFile -Confirm:$false -Force | Out-Null }
    Invoke-WebRequest -URI $rubyURL -OutFile $tempFile 

    & 7z x $tempFile "`"-o$tempExtract`"" -y

    # Get the root directory from the extract
    $misc = (Get-ChildItem -Path $tempExtract | ? { $_.PSIsContainer } | Select -First 1).Fullname

    Write-Host "Install ruby to $destDir ..."
    if (Test-Path -Path $destDir) { Remove-Item -Path $destDir -Recurse -Confirm:$false -Force | Out-Null }
    Move-Item -Path $misc -Destination $destDir -Force -Confirm:$false | Out-Null

    Write-Host "Cleaning up..."
    if (Test-Path -Path $tempFile) { Remove-Item -Path $tempFile -Confirm:$false -Force | Out-Null }
    if (Test-Path -Path $tempExtract) { Remove-Item -Path $tempExtract -Recurse -Confirm:$false -Force | Out-Null }
  } else { Write-Host "Ruby is already installed to $destDir"}

  Write-Host "Adding to URU..."
  & uru admin add "$($destDir)\bin" --tag $(Get-UruTag $rubyVersion)

}

# Now configure each ruby...
$itemsToInstall.GetEnumerator() | % {
  $rubyVersion = $_.Key
  Write-Host "------ Configuring $rubyVersion ..."

  & uru $(Get-UruTag $rubyVersion)
  Write-Output "Ruby version..."
  & ruby -v
  Write-Output "Gem version..."
  & gem -v

  # Create temporary gemrc for http
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

  $devkitDir = ''
  if ($rubyVersion -match '^1\.') {
    Write-Output "Installing bundler..."
    & gem install bundler --no-ri --no-rdoc
    $devkitDir = $devKit1x    
  } else {
    Write-Output "Installing bundler..."
    & gem install bundler --no-ri --no-rdoc --no-document
    if ($rubyVersion -match 'x64') {
      $devkitDir = $devKit2_64 
    } else {
      $devkitDir = $devKit2_32 
    }
  } 

  # Install DevKit ...
@"
---
- $( (Get-DestDir($rubyVersion)) -replace '\\','/' )
"@ | Set-Content -Path "$($devkitDir)\config.yml"
  Push-Location $devkitDir
  Write-Host "Installing DevKit $devKit for $rubyVersion"
  & ruby dk.rb install
  Pop-Location
}

Write-Host "Cleanup URU assignment"
& uru nil

Write-Host "Available ruby list" -ForegroundColor Green
Write-Host "-------------------" -ForegroundColor Green
& uru list
