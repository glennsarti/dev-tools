param([Switch]$Install)

if ($Install) {
  $ProfileFile = Join-Path -Path ([environment]::getfolderpath("mydocuments")) -ChildPath 'WindowsPowerShell\Profile.ps1'

  if (-not (Test-Path -Path $ProfileFile)) {
    ". `"$PSCommandPath`"" | Set-Content $ProfileFile -Encoding UTF8 -Force -Confirm:$false
  } else {
    "`n. `"$PSCommandPath`"" | Out-File $ProfileFile -Encoding UTF8 -Append -Force -Confirm:$false
  }
}

If ($ENV:ConEmuHWND -eq $null) {
  Import-Module PSConsoleTheme
  Set-ConsoleTheme 'Solarized Dark'
}
