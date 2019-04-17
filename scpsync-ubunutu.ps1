param(
  $target = '',
  $destDir = '',
  [Switch]$PrepTarget
)
$ErrorActionPreference = 'Stop'

# choco install openssh -y -params '"/SSHServerFeature"'

$thisDir = Get-Location
if ($destDir -eq '') { $destDir = '/source/' + (Split-Path -Path (Get-Location) -Leaf) }

if ($PrepTarget) {
  Write-Host "Preparing Target machine..."

  Invoke-Command -ComputerName $target -Credential (Get-Credential 'Administrator') -ArgumentList @($destDir) -ScriptBlock {
    param($destDir)
    if (-Not (Test-Path -Path $destDir)) {
      Write-Host "Creating destination dir..."
      New-Item $destDir -ItemType Directory | Out-Null
    }

    & choco install openssh -y -params '"/SSHServerFeature"'
  }
}

Write-Host "Connecting to $target ..."
& "C:\Program Files (x86)\WinSCP\WinSCP.com" /ini=nul /script=C:\Source\dev-tools\scpsync-ubuntu.script /parameter $target ($thisDir -replace '\\','/') ($destDir -replace '\\','/')

#Write-Host ($target, ($thisDir -replace '\\','/'), ($destDir -replace '\\','/'))
