param([Switch]$Install)

if ($Install) {
  $ProfileFile = $PROFILE # Join-Path -Path ([environment]::getfolderpath("mydocuments")) -ChildPath 'WindowsPowerShell\Profile.ps1'

  if (-not (Test-Path -Path $ProfileFile)) {
    ". `"$PSCommandPath`"" | Set-Content $ProfileFile -Encoding UTF8 -Force -Confirm:$false
  } else {
    "`n. `"$PSCommandPath`"" | Out-File $ProfileFile -Encoding UTF8 -Append -Force -Confirm:$false
  }
  return
}

If (($null -eq $ENV:ConEmuHWND) -and ($ENV:TERM_PROGRAM -ne 'vscode')) {
  # Import-Module PSConsoleTheme
  # Set-ConsoleTheme 'Bright'
  Set-Location C:\Source
}

Import-Module Posh-Git
