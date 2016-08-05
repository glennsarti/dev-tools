Param($VMName = '')
$ErrorActionPreference = 'Stop'

$vmList = @{}
Get-VM | % {
  $thisVM = $_

  $hasDiffDisk = $false
  $thisVM | Get-VMHardDiskDrive | Get-VHD | ? { $_.VhdType -eq 'Differencing' } | % {
    $hasDiffDisk = $true
  }

  if ($hasDiffDisk) { $vmList.Add($thisVM.Name,$thisVM) }
}


# Get Template Name if not supplied
while (-not ($vmList.ContainsKey($VMName))) {
  Write-Host "Remove VM"
  $vmList.GetEnumerator() | % {
    Write-Host "- $($_.Key)"
  }
  $VMName = Read-Host -Prompt "Enter VM Name"
}


$diskList = ($vmList.Item($VMName) | Get-VMHardDiskDrive | Get-VHD | % { Write-Output $_.Path })

Write-Host "Removing VM..."
$vmList.Item($VMName) | Stop-VM -Confirm:$false -Force -TurnOff -Save:$false -ErrorAction 'SilentlyContinue'
$vmList.Item($VMName) | Remove-VM -Confirm:$false -Force | Out-Null
Write-Host "Removing Disks..."
$diskList | Remove-Item -Force -Confirm:$false | Out-Null
