param(
  $ExternalAdapterName = $null
)
$ErrorActionPreference = 'Stop'

$ThisHost = Get-VMHost | Select-Object -First 1

$VHDPath = 'C:\HyperV\Disks'
if ($ThisHost.VirtualHardDiskPath -ne $VHDPath) {
  $ThisHost | Set-VMHost -VirtualHardDiskPath $VHDPath
} else { Write-Host "VM Disk Path is correct" -ForegroundColor Green }

$VMPath = 'C:\HyperV\VMs'
if ($ThisHost.VirtualMachinePath -ne $VMPath) {
  $ThisHost | Set-VMHost -VirtualMachinePath $VMPath
} else { Write-Host "VM Path is correct" -ForegroundColor Green }

# Setup an External VSwitch
$ExternalSwitch = Get-VMSwitch | ? { $_.Name -eq 'External' }
if ($null -eq $ExternalSwitch) {
  if ($null -eq $ExternalAdapterName) {
    Write-Host "Available network adapters:"
    Get-NetAdapter | Format-Table
    Throw "ExternalAdapterName is required"
    return;
  }
  Write-Host "Creating External VSwitch ($ExternalAdapterName)..."
  New-VMSwitch -Name 'External' -AllowManagementOS $True -NetAdapterName $ExternalAdapterName
} else {
  Write-Host "External VSwitch Exists" -ForegroundColor Green
}

$InternalVNicName = 'Internal (with NAT)'

$InternalNATSwitch = Get-VMSwitch | ? { $_.Name -eq $InternalVNicName }
if ($null -eq $InternalNATSwitch) {
  Write-Host "Creating Internal NAT vSwitch..."
  New-VMSwitch -Name $InternalVNicName -SwitchType Internal
  # Need a delay to allow the VNic to be created.
  Start-Sleep -Seconds 2
} else {
  Write-Host "Internal NAT VSwitch Exists" -ForegroundColor Green
}

$InternalNIC = Get-NetAdapter -Name "vEthernet ($($InternalVNicName))"
if ($null -eq $InternalNIC) {
  Throw "Internal NAT Nic is missing!!"
  return;
}

$ip = Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias "vEthernet ($($InternalVNicName))"
if ($ip.ToString() -ne '192.168.200.1' ) {
  New-NetIPAddress -InterfaceAlias "vEthernet ($($InternalVNicName))" -IPAddress '192.168.200.1' -AddressFamily IPv4
} else { Write-Host "Internal NAT Interface is configured" -ForegroundColor Green }

# Reset NAT
$nat = Get-NetNat | Select -First 1
if (($null -eq $nat) -or ($nat.Name -ne 'Internal HyperV NAT')) {
  Get-NetNat | Remove-Netnat -Confirm:$false | Out-Null
  New-NetNat -Name 'Internal HyperV NAT' -InternalIPInterfaceAddressPrefix '192.168.200.0/24'
} else { Write-Host "Internal NAT is configured" -ForegroundColor Green }

# Setup DHCP
if (!(Test-Path -Path HKLM:\SYSTEM\CurrentControlSet\services\DHCPServerHelper)) {
  # Install service
  & 'C:\HyperV\Helpers\dhcpd\dhcpsrv.exe' -install
  # Rename service name due to a conflict.
  Rename-Item HKLM:\SYSTEM\CurrentControlSet\services\DHCPServer DHCPServerHelper
  Set-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\services\DHCPServerHelper -Name 'DisplayName' -Value 'DHCP Server (Helper)'
  # Add Firewall config
  & 'C:\HyperV\Helpers\dhcpd\dhcpsrv.exe' -configfirewall
} else { Write-Host "DHCP Server is configured" -ForegroundColor Green }
