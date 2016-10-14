$ErrorActionPreference = 'Stop'

$userDir = Join-Path -Path $ENV:USERPROFILE -ChildPath '.puppetlabs'
$userClientToolsDir = Join-Path -Path $userDir -ChildPath 'client-tools'
$tokenFile = Join-Path -Path $userDir -ChildPath 'token'
$certsDir = 'C:\ProgramData\PuppetLabs\puppet\etc\ssl\certs'

## DANGER - Major hack
Add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class IDontCarePolicy : ICertificatePolicy {
        public IDontCarePolicy() {}
        public bool CheckValidationResult(
            ServicePoint sPoint, X509Certificate cert,
            WebRequest wRequest, int certProb) {
            return true;
        }
    }
"@

Function Invoke-ShowConfiguration() {
  Write-Host ""
  Write-Host "Gathering information from the PE Client Tools configuration..."

  if (-not (Test-Path -Path $userDir)) {
    Write-Warning "The PuppetLabs user directory is missing.  Expected to find '$$userDir'"
  }

  if (Test-Path -Path $tokenFile) {
    $fileInfo = Get-Item -Path $tokenFile
    Write-Host "Token file was last updated $($fileInfo.LastWriteTime)" -Foreground Green
  } else {
    Write-Warning "A token file from the Puppet RBAC service is expected at '$tokenFile'"
  }

  # Check config Files
  'puppet-code.conf','puppetdb.conf','puppet-access.conf','orchestrator.conf' | % {
    $filepath = Join-Path -Path $userClientToolsDir -ChildPath $_
    if (Test-Path -Path $filePath) {
      Write-Host "PE Client Tools configuration file '$_'" -Foreground Green
      Get-Content -Path $filePath
    
    } else {
      Write-Warning "Missing configuration file '$filepath'"
    }
  }

}

Function Invoke-QuickConfig() {
  Write-Host "Creating required directories..."
  # Quick hack but it works ...
  if (-Not (Test-Path -Path $certsDir)) {
    (& cmd /c md "`"$certsDir`"") | Out-Null
  }
  if (-Not (Test-Path -Path $userClientToolsDir)) {
    (& cmd /c md "`"$userClientToolsDir`"") | Out-Null
  }

  $puppetMaster = Read-Host "Enter Puppet Master name"
 
  # Sanity Check - Resolve by name
  try {
    Write-Host "Attempting to resolve $puppetMaster ..."
    $result = [System.Net.Dns]::gethostentry($puppetMaster)
    Write-Host "$puppetMaster has resolved to IP $($result.AddressList)"
  } catch {
    Write-Warning "Unable to resolve $puppetMaster by name"
    return
  }

  # Get the master certificate...
  $caCertFile = Join-Path -Path $certsDir -ChildPath 'ca.pem'
  if (Test-Path -Path $caCertFile) {
    Write-Host "Removing previous CA Master certificate..."
    Remove-Item -Path $caCertFile -Force -Confirm:$false | Out-Null
  }
  [System.Net.ServicePointManager]::CertificatePolicy = new-object IDontCarePolicy
  Write-Host "Fetching the CA Master certificate ..."
  $response = Invoke-WebRequest -URI "https://$($puppetMaster):8140/puppet-ca/v1/certificate/ca" -UseBasicParsing
  if ($response.StatusCode -ne 200) { Write-Warning "Response code $($response.StatusCode) from Puppet Master was not OK."; return }
  $response.Content | Out-File -FilePath $caCertFile -Encoding "ASCII"
  
  Write-Host "Writing config files with defaults..."
  # Write the config files
@"
{
    "service-url": "https://$($puppetMaster):4433/rbac-api"
}
"@ | Out-File -FilePath (Join-Path -Path $userClientToolsDir -ChildPath 'puppet-access.conf') -Encoding "ASCII"

@"
{
  "options" : {
    "service-url": "https://$($puppetMaster):8143"
  }
}
"@ | Out-File -FilePath (Join-Path -Path $userClientToolsDir -ChildPath 'orchestrator.conf') -Encoding "ASCII"

@"
{
  "service-url": "https://$($puppetMaster):8170/code-manager"
}
"@ | Out-File -FilePath (Join-Path -Path $userClientToolsDir -ChildPath 'puppet-code.conf') -Encoding "ASCII"

@"
{
  "puppetdb": {
    "server_urls": "https://$($puppetMaster):8081",
    "cacert": "$($caCertFile -replace '\\','\\')"
  }
}
"@ | Out-File -FilePath (Join-Path -Path $userClientToolsDir -ChildPath 'puppetdb.conf') -Encoding "ASCII"

  Write-Host "Quick configuration completed!"
  Invoke-ShowConfiguration
}

# Main
Write-Host "PE Client Tools Helper"
Write-Host "----------------------"

$PEClientToolsPath = 'C:\Program Files\Puppet Labs\Client'
$PEClientToolsBinPath = "$($PEClientToolsPath)\bin"

If (-not (Test-Path -Path $PEClientToolsBinPath)) {
  Write-Warning "Could not locate the PE Client Tools at '$($PEClientToolsPath)'"
  return 
}

$validOptions = @('1','2','3')

# Show Menu
Write-Host '1. Start the PE Client Tools Shell'
Write-Host '2. Show current PE Client Tool configuration'
Write-Host '3. Quick config PE Client Tools'
Write-Host ''
do {
  $option = Read-Host -Prompt "Enter select ($($validOptions -join ','))"
} until ($validOptions -contains $option)

switch ($option) {
  '1' { Start-Process -FilePath "cmd.exe" -Argument @('/k',"`"$($PEClientToolsBinPath)\pe_client_shell.bat`"") | Out-Null }
  '2' { Invoke-ShowConfiguration }
  '3' { Invoke-QuickConfig }
}
