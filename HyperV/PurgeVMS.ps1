$ErrorActionPreference = 'Stop'

# Removes VM files that do not exist in the HyperV host
$rootPath = 'C:\HyperV\VMs\Virtual Machines\'

$currentVMs = (Get-VM | % { Write-Output $_.Id.ToString().ToLower() })
if ($null -eq $currentVMs) { $currentVMs = @() }
if ($currentVMs.GetType().ToString() -ne 'System.Object[]') { $currentVMs = @($currentVMs) }

Function Remove-VMFiles($VMConfig) {
  $basename = $VMConfig.BaseName

  Get-ChildItem -Path $rootPath -Filter "$basename.*" -File | ForEach-Object {
    Write-Host "Removing $($_.FullName)" -ForegroundColor Yellow
    Remove-Item $_.FullName -Confirm:$false -Force | Out-Null
  }

  $VMPath = Join-Path $rootPath $basename
  if (Test-Path -Path $VMPath) {
    Write-Host "Removing $VMPath" -ForegroundColor Yellow
    Remove-Item $VMPath -Recurse -Confirm:$false -Force | Out-Null
  }
}

Get-ChildItem -Path $rootPath -File |
  ? { $_.Extension.ToUpper() -eq '.VMCX'} |
  % {

    if ($currentVMs -contains $_.BaseName.ToLower()) {
      Write-Host "${_} is already imported.  Ignoring" -ForegroundColor Green
    } else {
      Remove-VMFiles $_
    }
  }
