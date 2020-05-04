$ErrorActionPreference = 'Stop'

Function Expand-VMConfig ($VMConfig) {
  $tempVM = (Compare-VM -Copy -Path $VMConfig -GenerateNewID).VM

  write-host 'VM Configuration Data'
  write-host '====================='
  $tempVM | Select *

  write-host 'VM Network Adapters'
  write-host '====================='
  $tempVM.NetworkAdapters

  write-host 'VM Hard Drives'
  write-host '====================='
  $tempVM.HardDrives

  write-host 'VM DVD Drives'
  write-host '====================='
  $tempVM.DVDDrives

  write-host 'VM Floppy Drive'
  write-host '====================='
  $tempVM.FloppyDrive

  write-host 'VM Fibre Channel'
  write-host '====================='
  $tempVM.FibreChannelHostBusAdapters

  write-host 'VM COM1'
  write-host '====================='
  $tempVM.ComPort1

  write-host 'VM COM2'
  write-host '====================='
  $tempVM.ComPort2
}

$rootPath = 'C:\HyperV\VMs\Virtual Machines\'

$currentVMs = (Get-VM | % { Write-Output $_.Id.ToString().ToLower() })
if ($null -eq $currentVMs) { $currentVMs = @() }
if ($currentVMs.GetType().ToString() -ne 'System.Object[]') { $currentVMs = @($currentVMs) }

# Write-Host ($currentVMs | COnvertTo-JSON) -ForegroundColor Magenta

Function Import-Master($VMConfig) {
  try {
    $CompareResult = Compare-VM -Copy -Path $VMConfig.FullName -GenerateNewID -ErrorAction Stop
    $tempVM = $CompareResult.VM

    if ($CompareResult.Incompatibilities.Count -gt 0) {
      Write-Host "VM (${VMConfig}) $($tempVM.VMName) has Incompatibilities..." -ForegroundColor Red
      Write-Host ($CompareResult.Incompatibilities | Select-Object Message) -ForegroundColor Red
      return
    }
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

  Import-VM -Path $VMConfig.FullName -Confirm:$false -ErrorAction Continue
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
