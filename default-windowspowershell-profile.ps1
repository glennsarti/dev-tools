param([Switch]$Install)

if ($Install) {
  $ProfileFile = $PROFILE # Join-Path -Path ([environment]::getfolderpath("mydocuments")) -ChildPath 'WindowsPowerShell\Profile.ps1'
  $ProfilePath = Split-Path $ProfileFile -Parent
  if (-not (Test-Path -Path $ProfilePath)) { New-Item -Path $ProfilePath -ItemType Directory -Force -Confirm:$false | Out-Null }

  if (-not (Test-Path -Path $ProfileFile)) {
    ". `"$PSCommandPath`"" | Set-Content $ProfileFile -Encoding UTF8 -Force -Confirm:$false
  } else {
    "`n. `"$PSCommandPath`"" | Out-File $ProfileFile -Encoding UTF8 -Append -Force -Confirm:$false
  }

  Install-Module Posh-Git
  return
}

If (($null -eq $ENV:ConEmuHWND) -and ($ENV:TERM_PROGRAM -ne 'vscode')) {
  # Import-Module PSConsoleTheme
  # Set-ConsoleTheme 'Bright'
  Set-Location C:\Source
}

Import-Module Posh-Git
$ENV:Path = $ENV:Path + ";$PSScriptRoot"