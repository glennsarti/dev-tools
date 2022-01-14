# Assumes Docker Desktop for Windows is already installed

# On an online machine, download the zip file.
$OutFile = Join-Path $ENV:TEMP 'docker-19.03.5.zip'
Invoke-WebRequest -UseBasicParsing -OutFile $OutFile https://download.docker.com/components/engine/windows-server/19.03/docker-19.03.5.zip

# Extract the archive.
Expand-Archive $OutFile -DestinationPath $Env:ProgramFiles -Force

Start-Process -FilePath "$($Env:ProgramFiles)\docker\dockerd.exe" -ArgumentList @('--debug') -NoNewWindow:$false -Wait:$false

& docker pull mcr.microsoft.com/windows:1909
