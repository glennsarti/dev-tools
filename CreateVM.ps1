Param($Template = '', $VMName = '')
$ErrorActionPreference = 'Stop'

$DiskRoot = 'C:\HyperV\Disks'

$Templates = @{
  'Server2012R2' = @{
    'ParentDisk' = 'Server 2012 R2 - Master.vhdx'
    'DiskType' = 'vhdx'
    'Memory' = 4096 * 1024 * 1024
    'VMSwitch' = 'Internal (with NAT)'
    'Generation' = 2
    'vCPU' = 2
  }
}

# Get VM Name if not supplied
while ($VMName -eq '') {
  $VMName = Read-Host -Prompt "Enter VM Name"
}

# Get Template Name if not supplied
while (-not ($Templates.ContainsKey($Template))) {
  Write-Host "Templates:"
  $Templates.GetEnumerator() | % {
    Write-Host " - $($_.Key)"
  }

  $Template = Read-Host -Prompt "Enter Template Name"
}

$VMTemplate = $Templates."$Template" #"
$VMDiskName = Join-Path -Path $DiskRoot -ChildPath "$($VMName).$($VMTemplate.DiskType)"
$RootVMDisk = Join-Path -Path $DiskRoot -ChildPath "$($VMTemplate.ParentDisk)"

# Cleanup
Get-VM -Name $VMName -ErrorAction 'SilentlyContinue' | Remove-VM -Name $VMName -Confirm:$false -Force | out-Null
If (Test-Path -Path $VMDiskName) { Remove-Item -Path $VMDiskName -Confirm:$false -Force | Out-Null }

# Create the VM
$newVM = New-VM -Name $VMName -MemoryStartupBytes $VMTemplate.Memory -Generation $VMTemplate.Generation `
          -NoVHD -SwitchName $VMTemplate.VMSwitch -Confirm:$false |
          Set-VMProcessor -Count $VMTemplate.vCPU

# Create the disk
$newDisk = New-VHD -Path $VMDiskName -ParentPath $RootVMDisk -Differencing
# Attach the disk
Add-VMHardDiskDrive -VMName $VMName -Path $VMDiskName | Out-Null
