$rootPath = 'C:\HyperV\VMs\Virtual Machines\'

$currentVMs = (Get-VM | % { Write-Output $_.Id.ToString().ToLower() })
if ($currentVMs.GetType().ToString() -ne 'System.Object[]') { $currentVMs = @($currentVMs) }

Function Import-Master($VMConfig) {
  try {
    $tempVM = (Compare-VM -Copy -Path $VMConfig.FullName -GenerateNewID -ErrorAction Stop).VM
  } catch {
    Write-Host "Unable to query ${VMconfig.FullName}" -ForegroundColor Red
    return
  }

  $descriptiveName = "(${VMConfig}) $($tempVM.VMName)"
  write-Host "Checking ${descriptiveName}..." -ForegroundColor Yellow

  # Check the disks
  $disksAreReadyOnly = $true
  $tempVM.HardDrives | % {
    $disk = $_

    If (-Not (Test-Path -Path $disk.Path)) {
      $disksAreReadyOnly = $false
      Write-Host "Missing disk file $($disk.Path)" -ForegroundColor Red
    } else {
      if (-Not (Get-Item $disk.Path).IsReadOnly) {
        $disksAreReadyOnly = $false
        Write-Host "Disk file $($disk.Path) is not ReadOnly" -ForegroundColor Red
      }
    }

  }
  if (-not $disksAreReadyOnly) { return }

  # Import the VM
  Write-Host "Importing the VM" -ForegroundColor Cyan
  Import-VM -Path $VMConfig.FullName -Confirm:$false
}

Get-ChildItem -Path $rootPath -File |
  ? { $_.Extension.ToUpper() -eq '.VMCX'} |
  % {

    if ($currentVMs -contains $_.BaseName.ToLower()) {
      Write-Host "${_} is already imported.  Ignoring" -ForegroundColor Green
    } else {
      Import-Master $_
    }
  }
