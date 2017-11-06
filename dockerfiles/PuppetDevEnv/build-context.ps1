param($BaseImage = 'microsoft/windowsservercore', $include32bit = $false)
$ErrorActionPreference = 'Stop'

$TempDir = Join-Path -Path $PSScriptRoot -ChildPath 'tmp'
$contextDir = Join-Path -Path $PSScriptRoot -ChildPath 'context'
$rootArtifactDir = Join-Path -Path $contextDir -ChildPath 'tools'

if (-not (Test-Path -Path $TempDir)) { New-Item -Path $TempDir -ItemType Directory | Out-Null }
if (-not (Test-Path -Path $contextDir)) { New-Item -Path $contextDir -ItemType Directory | Out-Null }
if (-not (Test-Path -Path $rootArtifactDir)) { New-Item -Path $rootArtifactDir -ItemType Directory | Out-Null }

# Download Manifest
$DownloadManifest = @{
  'RubyDevkit2_x64' = @{
    'URL' = 'https://dl.bintray.com/oneclick/rubyinstaller/DevKit-mingw64-32-4.7.2-20130224-1151-sfx.exe';
    'Filename' = 'devkit.exe';
    'ArtifactDir' = 'devkit2_x64'
    'DLType' = 'DevKit';
  }
  # 'RubyDevkit2_x86' = @{
  #   'URL' = 'https://dl.bintray.com/oneclick/rubyinstaller/DevKit-mingw64-32-4.7.2-20130224-1151-sfx.exe';
  #   'Filename' = 'devkit.exe';
  #   'ArtifactDir' = 'devkit2'
  #   'DLType' = 'DevKit';
  # }
  'Ruby231_x64' = @{
    'URL' = 'https://dl.bintray.com/oneclick/rubyinstaller/ruby-2.3.1-x64-mingw32.7z';
    'Filename' = 'ruby.7z';
    'ArtifactDir' = 'ruby2_3_1-x64'
    'DLType' = 'Ruby';
  }
  # 'Ruby231_i386' = @{
  #   'URL' = 'https://dl.bintray.com/oneclick/rubyinstaller/ruby-2.3.1-i386-mingw32.7z';
  #   'Filename' = 'ruby.7z';
  #   'ArtifactDir' = 'ruby2_3_1'
  #   'DLType' = 'Ruby';
  # }
  'Ruby218_x64' = @{
    'URL' = 'https://dl.bintray.com/oneclick/rubyinstaller/ruby-2.1.8-x64-mingw32.7z';
    'Filename' = 'ruby.7z';
    'ArtifactDir' = 'ruby2_1_8-x64'
    'DLType' = 'Ruby';
  }
  # 'Ruby218_i386' = @{
  #   'URL' = 'https://dl.bintray.com/oneclick/rubyinstaller/ruby-2.1.8-i386-mingw32.7z';
  #   'Filename' = 'ruby.7z';
  #   'ArtifactDir' = 'ruby2_1_8'
  #   'DLType' = 'Ruby';
  # }
  'URU' = @{
    'URL' = 'https://bitbucket.org/jonforums/uru/downloads/uru-0.8.2-windows-x86.7z'
    'Filename' = 'uru.7z';
    'ArtifactDir' = 'uru'
    'DLType' = 'Uru';
  }
}

# Download temp files
$DownloadManifest.GetEnumerator() | % {
  $itemDirectory = Join-Path -Path $TempDir -ChildPath ($_.Key)
  $thisItem = $_.Value
  $artifactDir = Join-Path -Path $rootArtifactDir -ChildPath $($thisItem.ArtifactDir)

  Write-Host "Checking $($_.Key) ..."

  if (-not (Test-Path -Path $itemDirectory)) { New-Item -Path $itemDirectory -ItemType Directory | Out-Null }

  # Download the artifact
  $tempItem = Join-Path -Path $itemDirectory -ChildPath $($thisItem.Filename)
  if (-not (Test-Path -Path $tempItem)) {
    Write-Host "Downloading $($thisItem.URL) to $($tempItem) ..."
    (New-Object System.Net.WebClient).DownloadFile($thisItem.URL, $tempItem)
  }

  # Extract it
  If (-not (Test-Path -Path $artifactDir)) {  
    switch ($thisItem.DLType) {
      "DevKit" {
        Write-Host "Extracting DevKit ..."
        & 7z x $tempItem "`"-o$artifactDir`"" -y
      }
      "Uru" {
        Write-Host "Extracting Uru 7zip ..."
        & 7z x $tempItem "`"-o$artifactDir`"" -y

          $bat = @"
@echo off
rem autogenerated by uru

set URU_INVOKER=batch

"C:\tools\uru\uru_rt.exe" %*

if "x%URU_HOME%x"=="xx" (
  if exist "%USERPROFILE%\.uru\uru_lackee.bat" (call "%USERPROFILE%\.uru\uru_lackee.bat")
) else (
  if exist "%URU_HOME%\uru_lackee.bat" (call "%URU_HOME%\uru_lackee.bat")
)
"@

        $ps = @"
# autogenerated by uru

`$env:URU_INVOKER = 'powershell'

C:\tools\uru\uru_rt.exe `$args

if (`$env:URU_HOME) {
  if(Test-Path "`$env:URU_HOME\uru_lackee.ps1"){ & `$env:URU_HOME\uru_lackee.ps1 }
} else {
  if(Test-Path "`$env:USERPROFILE\.uru\uru_lackee.ps1"){ & `$env:USERPROFILE\.uru\uru_lackee.ps1 }
}
"@

        @{'uru.bat' = $bat; 'uru.ps1' = $ps}.GetEnumerator() | %{
          $sw = [System.IO.StreamWriter] "$(Join-Path $artifactDir $_.Name)"
          $sw.Write($_.Value)
          $sw.Close()
          $sw.Dispose()
        }
      }
      "Ruby" {
        Write-Host "Extracting Ruby..."
                
        $tempExtract = Join-Path -path $itemDirectory -ChildPath 'rubydl_extracted'
        if (Test-Path -Path $tempExtract) { Remove-Item -Path $tempExtract -Recurse -Confirm:$false -Force | Out-Null }
        & 7z x $tempItem "`"-o$tempExtract`"" -y

        # Get the root directory from the extract
        $misc = (Get-ChildItem -Path $tempExtract | ? { $_.PSIsContainer } | Select -First 1).Fullname

        Write-Host "Moving ruby to $artifactDir ..."
        Move-Item -Path $misc -Destination $artifactDir -Force -Confirm:$false | Out-Null
      }
    }
  }
}

# Now all the files are downloaded, create the context
Write-Host "Creating context..."
Copy-Item -Path "$PSScriptRoot\DockerFile" -Debug "$($contextDir)\Dockerfile" -Force -Confirm:$false | Out-Null
Copy-Item -Path "$PSScriptRoot\docker_file-build.ps1" -Debug "$($contextDir)\tools\docker_file-build.ps1" -Force -Confirm:$false | Out-Null