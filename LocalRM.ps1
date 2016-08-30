Param($VMName = '')
$ErrorActionPreference = 'Stop'

$vmList = Get-VM | ? { $_.State -eq 'Running' } | % { Write-Output $_.Name } | Sort-Object
if ($vmList -eq $null) { Write-Host 'No running VMs'; return }
if ($vmList.GetType().ToString() -eq 'System.String') { $vmList = @($vmList) }

# Get the VM Name
$vmName = ''
do {
  $index = 1
  Write-Host "Running VMs"
  $vmList | % {
    Write-Host "$($index). $($_)"
    $index++
  }
  $misc = Read-Host -Prompt "Select a VM (1..$($vmList.Length))"
  try {
    $vmName = $vmList[$misc - 1]
  } catch { $vmName = '' }
} while ($vmName -eq '')

$ips = Get-VM -Name $VMName | ?{$_.ReplicationMode -ne "Replica"} | Select -ExpandProperty NetworkAdapters | Select IPAddresses
if ($ips -eq $null) { Write-Host "$VMName has no IP Addresses"; return }
$itsIP = $ips.IPAddresses | ? { $_ -like '192.168.200.*' }
if ($itsIP -eq $null) { Write-Host "$VMName has no 192.168.200.x address"; return }

Enter-PSSession -ComputerName $itsIP -Credential (Get-Credential 'Administrator')
