Param(
  [parameter(Position=0)]
  [string]$VMName = '',

  [parameter(Position=1)]
  [string]$Template = '',

  [string]$RemoteUsername = 'Administrator',
  [string]$RemotePassword = 'Password1'
)
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
  'Ubuntu1604' = @{
    'ParentDisk' = 'Ubuntu 16.04 - Master.vhdx'
    'DiskType' = 'vhdx'
    'Memory' = 4096 * 1024 * 1024
    'VMSwitch' = 'Internal (with NAT)'
    'Generation' = 1
    'vCPU' = 2
  }
  'Ubuntu1604Desktop' = @{
    'ParentDisk' = 'Ubuntu 16.04 Desktop - Master.vhdx'
    'DiskType' = 'vhdx'
    'Memory' = 4096 * 1024 * 1024
    'VMSwitch' = 'Internal (with NAT)'
    'Generation' = 1
    'vCPU' = 2
  }
  'WindowsContainerHost' = @{
    'ParentDisk' = 'Server 2016 RTM - Master.vhdx'
    'DiskType' = 'vhdx'
    'Memory' = 4096 * 1024 * 1024
    'VMSwitch' = 'Internal (with NAT)'
    'Generation' = 2
    'vCPU' = 2
    'PostCommands' = @(
      'netsh advfirewall firewall add rule name="All Incoming" dir=in action=allow enable=yes interfacetype=any profile=any localip=any remoteip=any',
      'netsh advfirewall firewall add rule name="All Outgoing" dir=out action=allow enable=yes interfacetype=any profile=any localip=any remoteip=any',
      'Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force',
      'Install-Module -Name DockerMsftProvider -Repository PSGallery -Force',
      'Install-Package -Name docker -ProviderName DockerMsftProvider -Force',
      "`"{`n    ```"hosts```": [```"tcp://0.0.0.0:2375```", ```"npipe://```"]`n    ```"insecure-registries```": [```"10.0.0.0/8```"]`n        }`" | Set-Content -Path 'C:\ProgramData\docker\config\daemon.json' -Encoding ASII"
      'Restart-Computer -Force',
      'docker --version',
      'docker network create -d transparent TransparentNetworkDHCP',
      'docker network create -d transparent --subnet=192.168.200.0/24 --gateway=192.168.200.1 TransparentNetwork',
      'docker pull microsoft/nanoserver',
      'docker pull microsoft/windowsservercore'
    )
  }
}

# TODO Add portainer to script
# https://hub.docker.com/r/portainer/portainer/tags/
# https://portainer.readthedocs.io/en/latest/deployment.html#deployment
# https://github.com/portainer/portainer/releases

# BEGIN Helper Functions
Function Get-IPFromVMName($VMName, $timeout = 120) {
  $itsIP = $null
  $attempt = [int]($timeout / 2)
  Write-Host "Waiting $($attempt*2) seconds for IP..."
  do {
    $ips = Get-VM -Name $VMName | ?{$_.ReplicationMode -ne "Replica"} | Select -ExpandProperty NetworkAdapters | Select IPAddresses
    $itsIP = $ips.IPAddresses | ? { $_ -like '192.168.200.*' }
    $attempt--
    if ($itsIP -eq $null -and $attempt -ne 0) { Start-Sleep -Seconds 2 }
  } until (($attempt -le 0) -or ($itsIP -ne $null))
  if ($itsIP -ne $null) { Write-Output $itsIP }
}
# END Helper Functions

# Get VM Name if not supplied
while ($VMName -eq '') {
  $VMName = Read-Host -Prompt "Enter VM Name"
}

# Get Template Name if not supplied
while (-not ($Templates.ContainsKey($Template))) {
  Write-Host "Templates:"
  $Templates.GetEnumerator() | Sort-Object Key | % {
    Write-Host " - $($_.Key)"
  }

  $Template = Read-Host -Prompt "Enter Template Name"
}

$VMTemplate = $Templates."$Template"
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
if ($VMTemplate.Generation -eq '2') {
  Write-Host "Setting first boot device to Disk..."
  Set-VMFirmware -VMName $VMName -FirstBootDevice (Get-VMHardDiskDrive -VMName $VMName)
}

# Start the VM
Write-Host "Starting the VM..."
Start-VM -Name $VMName -AsJob | Out-Null

$vmIP = Get-IPFromVMName -VMName $VMName
Write-Host $vmIP

# Run any Post Commands if specified
If ($VMTemplate.PostCommands -ne $null) {
  $secpasswd = ConvertTo-SecureString $RemotePassword -AsPlainText -Force
  $winrmCreds = New-Object System.Management.Automation.PSCredential ($RemoteUsername, $secpasswd)

  $VMTemplate.PostCommands | % {
    # Wait for WinRM to become available (120s timeout)
    $attempt = 60
    Write-Host "Waiting $($attempt*2) seconds for WinRM..."
    do {
      $isUp = $false
      try {
        Test-WSMan -Computer $vmIP -Credential $winrmCreds -Authentication Default | Out-Null
        $isUp = $true
     }
     catch [System.Exception] {
       $isUp = $false
     }
      $attempt--
      if ((!$isUp) -and $attempt -ne 0) { Start-Sleep -Seconds 2 }
    } until (($attempt -le 0) -or ($isUp))
    $cmd = $_
    Write-Host "Runnning command: $cmd ..."
    try {
      Invoke-Command -ComputerName $vmIP -Credential $winrmCreds -ArgumentList @($cmd) -ScriptBlock {
        param($cmd)
        Invoke-Expression -Command $cmd
      }
    }
    catch [System.Exception] {
      Write-Warning "REMOTE ERROR: $_"
    }
  }
}
