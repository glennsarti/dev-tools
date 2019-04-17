param([Switch]$Force)
$ErrorActionPreference = 'Stop'

$RootDir = Join-path -Path $PSScriptRoot -ChildPath 'portainer_data'
If (-not(Test-Path -Path $RootDir)) { New-Item -ItemType Directory -Path $RootDir | Out-Null }

$PortainerDir = Join-Path -Path $RootDir -ChildPath 'portainer'
$DataDir = Join-Path -Path $RootDir -ChildPath 'data'
If (-not(Test-Path -Path $DataDir)) { New-Item -ItemType Directory -Path $DataDir | Out-Null }
$FlagFile = Join-Path -Path $RootDir -ChildPath "check.flag"

Function Update-Portainer {
  [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
  Write-Host "Checking if Portainer is latest..."
  $result = Invoke-RestMethod -Uri 'https://api.github.com/repos/portainer/portainer/releases/latest' -UseBasicParsing -Method Get

  $asset = $result.assets | Where-Object { $_.name -match 'windows\-amd64\.tar\.gz'} | Select-Object -First 1
  $asset_filename = Join-Path -Path $RootDir -ChildPath $asset.name

  if (!(Test-Path -Path $asset_filename)) {
    Write-Host "Downloading Portainer..."
    Invoke-WebRequest -Uri $asset.browser_download_url -UseBasicParsing -OutFile $asset_filename
  } else {
    Write-Host "Portainer is up to date."
    return
  }

  If (Test-Path -Path $PortainerDir) {
    Write-Host "Clearing out old portainer installation..."
    Remove-Item $PortainerDir -Force -Recurse -Confirm:$false | Out-Null
  }

  # Cleanup prior
  Get-ChildItem -Path "$RootDir\*.tar" | Remove-Item -Confirm:$false -Force | Out-Null

  Write-Host "Extracting gzip..."
  & 7z x $asset_filename -o"`"$RootDir`""

  Write-Host "Extracting tarball..."
  $asset_filename_tar = $asset_filename -replace ".gz$",""
  Write-Host $asset_filename_tar
  # We HOPE that portainer extracts to the child portainer directory...
  & 7z x $asset_filename_tar -o"`"$RootDir`""

  # Cleanup post
  Get-ChildItem -Path "$RootDir\*.tar" | Remove-Item -Confirm:$false -Force | Out-Null

  # Flag last update
  Get-Date | Out-File -FilePath $FlagFile
}

$DoUpdate = $false
if (Test-Path -Path $PortainerDir) {

  $fileCheck = Get-ChildItem -path $FlagFile -ErrorAction SilentlyContinue
  if ($null -eq $fileCheck) {
    Get-Date | Out-File -FilePath $FlagFile
  } else {
    $flagAge = New-TimeSpan -Start $fileCheck.LastWriteTime -End (Get-Date)
    $DoUpdate = ($flagAge.TotalDays -ge 14) # Check every two weeks
  }
} else {
  $DoUpdate = $true
}

if ($DoUpdate -or $Force) { Update-Portainer }

Write-Host 'Starting Portainer...'
Start-Process -FilePath (Join-Path -Path $PortainerDir -ChildPath 'portainer.exe') -WorkingDirectory $PortainerDir -ArgumentList @( `
  "--data=`"$DataDir`"", `
  "--template-file=`"$PortainerDir\templates.json`"", `
  "--host=tcp://127.0.0.1:2375"`
  ) -Wait:$false -NoNewWindow:$false | Out-Null

Start-Process 'http://localhost:9000'
