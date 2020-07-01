$result = Get-Command ruby.exe
$binPath = Split-Path -Path $result.Path -Parent

& $result.Path $binPath/bundle $args
