$ErrorActionPreference = 'Stop'

$uru = 'C:\tools\uru\uru.ps1'

function Get-UruTag($rubyDir) {
  $rubyDir = $rubyDir.replace('ruby','')
  $rubyDir = $rubyDir.replace('_','.')
  $bareRubyVersion = ($rubyDir -split '-')[0]

  if ($rubyDir -match 'x64') {
    Write-Output "$($bareRubyVersion)-x64"
  } else {
    Write-Output "$($bareRubyVersion)-x86"    
  }
}

Write-Host "Checking the SYSTEM Path..."
$Hive = [Microsoft.Win32.Registry]::LocalMachine
$Key = $Hive.OpenSubKey("SYSTEM\CUrrentControlSet\Control\Session Manager\Environment",$true)
$currentPath = $Key.GetValue("Path",$False, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)

if ($currentPath -notlike '*uru*') {
  Write-Host "Updating the SYSTEM Path..."
  $currentPath += ';C:\tools\uru'

  $Key.SetValue('PATH',$currentPath,[Microsoft.Win32.RegistryValueKind]::ExpandString)
}

# Configure each ruby
Get-ChildItem -Path 'C:\tools' | ? { $_.PSIsContainer } | ? { $_.Name -like 'ruby*' } | % { 
  $rubyFolder = $_
  $tagName = Get-UruTag $rubyFolder.Name

  Write-Host "------ Configuring $($rubyFolder.Name) ..."

  Write-Host "Adding $($rubyFolder.Fullname) to uru..."

  # Tag in uru
  & $uru admin add "$($rubyFolder.Fullname)\bin" --tag "$($tagName)"

  
  & $uru $(Get-UruTag $tagName)
  Write-Output "Ruby version..."
  & ruby -v
  Write-Output "Gem version..."
  & gem -v

  # Create temporary gemrc for http
  $tempRC =  Join-Path -path $ENV:Temp -ChildPath 'gem.rc'
@"
---
:backtrace: false
:bulk_threshold: 1000
:sources:
- http://rubygems.org
:update_sources: true
:verbose: true
"@ | Set-Content -Encoding Ascii -Path $tempRC -Force -Confirm:$false

  Write-Host "Updating system gems (via HTTP)..."
  if ($rubyVersion -match '^1\.') {
    & gem update --system --no-rdoc --config-file $tempRC
  } else {
    & gem update --system --no-rdoc --no-document --config-file $tempRC
  }
  Remove-Item -Path $tempRC -Force -Confirm:$false | Out-Null

  Write-Output "Installing bundler..."
  & gem install bundler --no-ri --no-rdoc --no-document

  # Install DevKit ...
  if ($tagName -match 'x64') {
    $devkitDir = 'C:\tools\devkit2_x64'
  } else {
    $devkitDir = 'c:\tools\devkit2'
  }
@"
---
- $( ($rubyFolder.Fullname) -replace '\\','/' )
"@ | Set-Content -Path "$($devkitDir)\config.yml"
  Push-Location $devkitDir
  Write-Host "Installing DevKit $devKit for $tagName"
  & ruby dk.rb install
  Pop-Location
}
