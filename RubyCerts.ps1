$CACertFile = Join-Path -Path $ENV:AppData -ChildPath 'RubyCACert.pem'

If (-Not (Test-Path -Path $CACertFile)) {
  Write-Output "Downloading CA Cert bundle..."
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  Invoke-WebRequest -Uri 'https://curl.haxx.se/ca/cacert.pem' -UseBasicParsing -OutFile $CACertFile | Out-Null
}

Write-Output "CA Certificate store set to ${CACertFile}"
$ENV:SSL_CERT_FILE = $CACertFile
[System.Environment]::SetEnvironmentVariable('SSL_CERT_FILE',$CACertFile, [System.EnvironmentVariableTarget]::Machine)
