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
  'Server2016RS1' = @{
    'ParentDisk' = 'Server 2016 RTM - Master.vhdx'
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

# Set the Boot Order...
Write-Host "Setting first boot device to Disk..."
Set-VMFirmware -VMName $VMName -FirstBootDevice (Get-VMHardDiskDrive -VMName $VMName)

# Start the VM
Write-Host "Starting the VM..."
Start-VM -Name $VMName -AsJob | Out-Null

$itsIP = $null
$attempt = 60
Write-Host "Waiting $($attempt*2) seconds for IP..."
do {
  $ips = Get-VM -Name $VMName | ?{$_.ReplicationMode -ne "Replica"} | Select -ExpandProperty NetworkAdapters | Select IPAddresses
  $itsIP = $ips.IPAddresses | ? { $_ -like '192.168.200.*' }
  $attempt--
  if ($itsIP -eq $null -and $attempt -ne 0) { Start-Sleep -Seconds 2 }
} until (($attempt -le 0) -or ($itsIP -ne $null))
Write-Host $itsIP