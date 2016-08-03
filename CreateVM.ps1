Param($Template = 'Server2012R2', $VMName = '')
$ErrorActionPreference = 'Stop'

$DiskRoot = 'C:\HyperV\Disks'

$Templates = @{
  'Server2012R2' = @{
    'ParentDisk' = 'Server 2012 R2 - Master.vhdx'
    'DiskType' = 'vhdx'
    'Memory' = 4096 * 1024 * 1024
    'VMSwitch' = 'Internal with NAT - Main'
    'Generation' = 2
    'vCPU' = 2
  }
}

# TODO
# Prompt for template and VM Name

$VMTemplate = $Templates."$Template" #"
$VMDiskName = Join-Path -Path $DiskRoot -ChildPath "$($VMName).$($VMTemplate.DiskType)"
$RootVMDisk = Join-Path -Path $DiskRoot -ChildPath "$($VMTemplate.ParentDisk)"

# Cleanup
Remove-VM -Name $VMName -Confirm:$false -Force | out-Null
If (Test-Path -Path $VMDiskName) { Remove-Item -Path $VMDiskName -Confirm:$false -Force | Out-Null }

# Create the VM
$newVM = New-VM -Name $VMName -MemoryStartupBytes $VMTemplate.Memory -Generation $VMTemplate.Generation `
          -NoVHD -SwitchName $VMTemplate.VMSwitch -Confirm:$false |
          Set-VMProcessor -Count $VMTemplate.vCPU

# Create the disk
$newDisk = New-VHD -Path $VMDiskName -ParentPath $RootVMDisk -Differencing
# Attach the disk
Add-VMHardDiskDrive -VMName $VMName -Path $VMDiskName | Out-Null
