# From Facter Appveyor file
# https://github.com/puppetlabs/facter/blob/master/appveyor.yml
# This script requires Powershell 3.0

$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'

# Sanity Checks
Write-Verbose 'Sanity checks...'
# 64bit OS
if ([IntPtr]::Size -ne 8) { Throw 'This is not a 64bit Operating System'; return }
# Choco
$chocoExe = Get-Command 'choco' -ErrorAction SilentlyContinue
if ($chocoExe -eq $null)  {
  Write-Host "Chocolatey is not installed or can not be located.  If you've installed Chocolatey recently"
  Write-Host "please close this window and start a new session first."
  Write-Host ""
  $misc = Read-Host -Prompt "Would you like to install Chocolatey? (Y/N)"
  if (($misc -eq 'Y') -or ($misc -eq 'y')) {
    Write-Host 'Starting the installation'
    iwr https://chocolatey.org/install.ps1 -UseBasicParsing | iex
    Write-Host "-------------------------------"
    Write-Host "You will need to shut down and restart powershell and/or consoles first prior to using choco."
    return;
  } else {
    Throw 'Chocolatey is not installed'; return
  }
}
# Ruby
$rubyExe = Get-Command 'ruby' -ErrorAction SilentlyContinue
if ($rubyExe -eq $null) {
  Write-Host "Ruby is not installed or can not be located.  If you've installed Ruby recently"
  Write-Host "please close this window and start a new session first."
  Write-Host ""
  $misc = Read-Host -Prompt "Would you like to install Ruby? (Y/N)"
  if (($misc -eq 'Y') -or ($misc -eq 'y')) {
    Write-Host 'Starting the installation'
    & choco install ruby -y
    Write-Host "-------------------------------"
    Write-Host "You will need to shut down and restart powershell and/or consoles first prior to using ruby."
    return;
  } else {
    Throw 'Ruby is not on the PATH'; return
  }
}
# Admin rights
if (-not [bool](([System.Security.Principal.WindowsIdentity]::GetCurrent()).groups -match "S-1-5-32-544")) { throw "This command is not running with administrative rights."; return; }

# Get default values:
$INSTALL_LOCATION = 'C:\buildtools'
#   Query github for latest versions of Leatherman and CPP HOCON
$response = Invoke-RestMethod -URI 'https://api.github.com/repos/puppetlabs/leatherman/releases/latest' -Verbose:$false
$LEATHERMAN_VERSION = $response.tag_name # '0.9.1'
$response = Invoke-RestMethod -URI 'https://api.github.com/repos/puppetlabs/cpp-hocon/releases/latest' -Verbose:$false
$CPPHOCON_VERSION = $response.tag_name # '0.1.3'

# User input time...
Write-Verbose "Prompting for tool information..."
$misc = Read-Host -Prompt "Please enter a Leatherman Version to use [Press enter to use $LEATHERMAN_VERSION])"
if ($misc -ne '') { $LEATHERMAN_VERSION = $misc}
$misc = Read-Host -Prompt "Please enter a CPP HOCON Version to use [Press enter to use $CPPHOCON_VERSION])"
if ($misc -ne '') { $CPPHOCON_VERSION = $misc}
$misc = Read-Host -Prompt "Please enter a location to store build tools [Press enter to use $INSTALL_LOCATION])"
if ($misc -ne '') { $INSTALL_LOCATION = $misc}

if (-not (Test-Path -Path $INSTALL_LOCATION)) { New-Item -Path $INSTALL_LOCATION -ItemType 'Directory' -Force -Confirm:$false | Out-Null}

Write-Verbose "Installing chocolatey packages..."
& choco install mingw-w64 -y --version '4.8.3' -source https://www.myget.org/F/puppetlabs
& choco install cmake -y --version '3.2.2' -source https://www.myget.org/F/puppetlabs
& choco install -y gettext --version '0.19.6' -source https://www.myget.org/F/puppetlabs
& choco install 7zip.commandline -y

# Modify the PATH
Write-Verbose "Modifying the PATH..."
if (-not ($ENV:Path -like '*C:\Program Files\gettext-iconv*')) {
  Write-Verbose "Adding gettext-iconv to the path..."
  $ENV:PATH = 'C:\Program Files\gettext-iconv;' + $ENV:PATH  
}
# MingW _MUST_ be at the beginning of the path
if (-not ($ENV:Path -like 'C:\tools\mingw64\bin*')) {
  Write-Verbose "Adding mingw64 to the path..."
  $ENV:PATH = 'C:\tools\mingw64\bin;' + $ENV:PATH  
}
$ENV:PATH = $ENV:PATH.Replace("Git\bin", "Git\cmd")
$ENV:PATH = $ENV:PATH.Replace("Git\usr\bin", "Git\cmd")

# Modify SYSTEM PATH if needed
$misc = Read-Host -Prompt "Should the PATH environment variable for the computer be modified too? (Y/N)"
if (($misc -eq 'Y') -or ($misc -eq 'y')) {
  Write-Warning "**** THIS MAY REQUIRE A LOGOFF OR REBOOT TO TAKE AFFECT ****"
  $Hive = [Microsoft.Win32.Registry]::LocalMachine
  $Key = $Hive.OpenSubKey("SYSTEM\CurrentControlSet\Control\Session Manager\Environment",$true)

  $CurrentPATH = $Key.GetValue("path",$False, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
  if (-not ($CurrentPATH -like '*C:\Program Files\gettext-iconv*')) {
    $CurrentPATH = 'C:\Program Files\gettext-iconv;' + $CurrentPATH
  }
  # MingW _MUST_ be at the beginning of the path
  if (-not ($CurrentPATH -like 'C:\tools\mingw64\bin*')) {
    $CurrentPATH = 'C:\tools\mingw64\bin;' + $CurrentPATH
  }
  
  $Key.SetValue('Path',$CurrentPATH,'ExpandString')
}

# Temp file for downloads
$tempFile = Join-Path -Path $ENV:Temp -ChildPath 'cpp-temp-download.7z'

# Get boost
$boostDir = Get-ChildItem -Path $INSTALL_LOCATION -Filter "boost_*"
if ($boostDir -eq $null) {
  Write-Verbose "Grabbing boost 4.8.3 ..."
  If (Test-Path -Path $tempFile) { Remove-Item -Path $tempFile -Force -Confirm:$false | Out-Null }
  (New-Object System.Net.WebClient).DownloadFile(
   'https://s3.amazonaws.com/kylo-pl-bucket/boost_1_57_0-x86_64_mingw-w64_4.8.3_win32_seh.7z', $tempFile)

  & 7z.exe x $tempFile "-o$($INSTALL_LOCATION)"
  
  $boostDir = Get-ChildItem -Path $INSTALL_LOCATION -Filter "boost_*"
}
Write-Verbose "Boost installed at $($boostDir.FullName)"

# Get yaml-cpp
$yamlcppDir = Get-ChildItem -Path $INSTALL_LOCATION -Filter "yaml-cpp-*"
if ($yamlcppDir -eq $null) {
  Write-Verbose "Grabbing yaml-app 0.5.1 ..."
  If (Test-Path -Path $tempFile) { Remove-Item -Path $tempFile -Force -Confirm:$false | Out-Null }
  (New-Object System.Net.WebClient).DownloadFile(
   'https://s3.amazonaws.com/kylo-pl-bucket/yaml-cpp-0.5.1-x86_64_mingw-w64_4.8.3_win32_seh.7z', $tempFile)

  & 7z.exe x $tempFile "-o$($INSTALL_LOCATION)"
  
  $yamlcppDir = Get-ChildItem -Path $INSTALL_LOCATION -Filter "yaml-cpp-*"
}
Write-Verbose "YAML CPP installed at $($yamlcppDir.FullName)"

# Get curl
$curlDir = Get-ChildItem -Path $INSTALL_LOCATION -Filter "curl-*"
if ($curlDir -eq $null) {
  Write-Verbose "Grabbing curl 7.42.1 ..."
  If (Test-Path -Path $tempFile) { Remove-Item -Path $tempFile -Force -Confirm:$false | Out-Null }
  (New-Object System.Net.WebClient).DownloadFile(
   'https://s3.amazonaws.com/kylo-pl-bucket/curl-7.42.1-x86_64_mingw-w64_4.8.3_win32_seh.7z', $tempFile)

  & 7z.exe x $tempFile "-o$($INSTALL_LOCATION)"
  
  $curlDir = Get-ChildItem -Path $INSTALL_LOCATION -Filter "curl-*"
}
Write-Verbose "Curl installed at $($curlDir.FullName)"

# Get leatherman
$leathermanDir = Get-ChildItem -Path $INSTALL_LOCATION -Filter "leatherman*"
if ($leathermanDir -eq $null) {
  Write-Verbose "Grabbing leatherman $LEATHERMAN_VERSION ..."
  If (Test-Path -Path $tempFile) { Remove-Item -Path $tempFile -Force -Confirm:$false | Out-Null }
  (New-Object System.Net.WebClient).DownloadFile(
   "https://github.com/puppetlabs/leatherman/releases/download/$LEATHERMAN_VERSION/leatherman.7z", $tempFile)

  & 7z.exe x $tempFile "-o$($INSTALL_LOCATION)"
  
  $leathermanDir = Get-ChildItem -Path $INSTALL_LOCATION -Filter "leatherman*"
}
Write-Verbose "Leatherman installed at $($leathermanDir.FullName)"

# Get cpphocon
$hoconDir = Get-ChildItem -Path $INSTALL_LOCATION -Filter "cpp-hocon*"
if ($hoconDir -eq $null) {
  Write-Verbose "Grabbing CPP HOCON $CPPHOCON_VERSION ..."
  If (Test-Path -Path $tempFile) { Remove-Item -Path $tempFile -Force -Confirm:$false | Out-Null }
  (New-Object System.Net.WebClient).DownloadFile(
   "https://github.com/puppetlabs/cpp-hocon/releases/download/$CPPHOCON_VERSION/cpp-hocon.7z", $tempFile)

  & 7z.exe x $tempFile "-o$($INSTALL_LOCATION)"
  
  $hoconDir = Get-ChildItem -Path $INSTALL_LOCATION -Filter "cpp-hocon*"
}
Write-Verbose "CPP HOCON installed at $($hoconDir.FullName)"


# Create helper batch and powershell scripts.  These are run from within a facter repos
# The helpers typically just setup the environment path first and then do 'something'

Write-Verbose "Create build batch files..."
@"
@ECHO OFF

SET PATH=$($ENV:PATH)

SET FACTER_SRC=.
if NOT [%1]==[] SET FACTER_SRC=%1

cmake -G `"MinGW Makefiles`" -DBOOST_ROOT=`"$($boostDir.FullName)`" -DYAMLCPP_ROOT=`"$($yamlcppDir.FullName)`" -DBOOST_STATIC=ON -DCURL_STATIC=ON -DCMAKE_INSTALL_PREFIX=`"C:\Program Files\FACTER`" -DCMAKE_PREFIX_PATH=`"$($leathermanDir.FullName);$($curlDir.FullName);$($hoconDir.FullName)`" %FACTER_SRC%
mingw32-make clean install -j2

"@ | Out-File -FilePath "$INSTALL_LOCATION\build-facter.bat" -Encoding 'ASCII'

@"
@ECHO OFF

SET PATH=$($ENV:PATH)

ECHO Ready for work
"@ | Out-File -FilePath "$INSTALL_LOCATION\build-env.bat" -Encoding 'ASCII'

Write-Verbose "Create test ps1 files..."
@"
`$ENV:PATH = `"$($ENV:PATH)`"

ctest -V 2>&1 | %{ if (`$_ -is [System.Management.Automation.ErrorRecord]) { `$_ | c++filt } else { `$_ } }
mingw32-make install

"@ | Out-File -FilePath "$INSTALL_LOCATION\test-facter.ps1" -Encoding 'ASCII'

@"
-----------------------------------------------------------------------
From within a puppetlabs-facter repository you can call:

$($INSTALL_LOCATION)\build-env.bat           Sets environment vars for building facter

$($INSTALL_LOCATION)\build-facter.bat        Builds facter from the root of a facter repo
$($INSTALL_LOCATION)\build-facter.bat <path> Builds facter with a path to the facter source e.g. in 'facter/release' would call '$($INSTALL_LOCATION)\build-facter.bat ..'

$($INSTALL_LOCATION)\test-facter.bat         Runs tests from the root of a facter repo

-----------------------------------------------------------------------
"@ | Write-Host -ForegroundColor Green
