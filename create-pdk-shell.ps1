$fso = New-Object -ComObject Scripting.FileSystemObject

$ENV:DEVKIT_BASEDIR = (Get-ItemProperty -Path "HKLM:\Software\Puppet Labs\DevelopmentKit").RememberedInstallDir64
# Windows API GetShortPathName requires inline C#, so use COM instead
$ENV:DEVKIT_BASEDIR = $fso.GetFolder($ENV:DEVKIT_BASEDIR).ShortPath
$ENV:RUBY_DIR       = "$($ENV:DEVKIT_BASEDIR)\private\ruby\2.1.9"
$ENV:SSL_CERT_FILE  = "$($ENV:DEVKIT_BASEDIR)\ssl\cert.pem"
$ENV:SSL_CERT_DIR   = "$($ENV:DEVKIT_BASEDIR)\ssl\certs"
# $ENV:GEM_HOME = Join-Path $ENV:LOCALAPPDATA 'PDK\cache\ruby\2.1.0'
$ENV:GEM_PATH = Join-Path $ENV:DEVKIT_BASEDIR 'share\cache\ruby\2.1.0'

#PATH=C:/PROGRA~1/PUPPET~1/DEVELO~1/private/ruby/2.1.9/bin;C:\Users\glenn.sarti\AppData\Local/PDK/cache/ruby/2.1.0/bin;C:/PROGRA~1/PUPPET~1/DevelopmentKit/share/cache/ruby/2.1.0/bin;C:/PROGRA~1/PUPPET~1/DevelopmentKit/bin

$ENV:Path = (Join-Path $ENV:RUBY_DIR 'bin') + ';' +
            (Join-Path $ENV:LOCALAPPDATA 'PDK\cache\ruby\2.1.0\bin') + ';' +
            (Join-Path $ENV:DEVKIT_BASEDIR 'share\cache\ruby\2.1.0\bin') + ';' +
            (Join-Path $ENV:DEVKIT_BASEDIR 'bin') + ';' + $ENV:Path
