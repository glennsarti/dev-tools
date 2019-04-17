
$title = (get-process POWERPNT -ErrorAction 'SilentlyContinue' | Select-Object -First 1).MainWindowTitle

if ($null -eq $title) { return }
$wshell = New-Object -ComObject wscript.shell;
$wshell.AppActivate($title)
Start-Sleep 1
$wshell.SendKeys('+{F5}')
