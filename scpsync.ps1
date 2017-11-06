param(
  $target = '',
  $destDir = ''
)
$ErrorActionPreference = 'Stop'

# choco install openssh -y -params '"/SSHServerFeature"'

$thisDir = Get-Location
if ($destDir -eq '') { $destDir = $thisDir }

Write-Host "Connecting to $target ..."
& "C:\Program Files (x86)\WinSCP\WinSCP.com" /ini=nul /script=C:\Source\dev-tools\scpsync.script /parameter $target ($thisDir -replace '\\','/') ($destDir -replace '\\','/')
