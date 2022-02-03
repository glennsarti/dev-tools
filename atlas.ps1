[CmdletBinding(SupportsShouldProcess=$true)]
param([Switch]$Force, [Switch]$Setup)

$ErrorActionPreference = 'Stop'

$CurrentDir = (Get-Location).Path

if (-Not (Test-Path (Join-Path $CurrentDir 'frontend/atlas'))) {
  Write-Host "-------------------------------------------" -Foreground Red
  Write-Host "I don't think you're in an Atlas repository" -Foreground Red
  Write-Host "-------------------------------------------" -Foreground Red
  Exit 1
}

if ($Setup.IsPresent) {
  $CAKey = Join-Path (Join-Path $PSScriptRoot 'atlas') 'internal-ca.pem'
  if (-Not (Test-Path $CAKey)) {
    Write-Host "Creating Internal CA Private Key..." -Foreground Green
    & openssl genrsa -out $CAKey 4096
  }
  $CAFile = Join-Path (Join-Path $PSScriptRoot 'atlas') 'internal-ca.crt'
  if (-Not (Test-Path $CAFile)) {
    Write-Host "Creating Internal CA Certificate..." -Foreground Green
    & openssl req -x509 -sha256 -new -nodes -key $CAKey -days 3650 -out $CAFile -subj "/C=AU/ST=WA/L=Perth/O=HashiCorp/CN=internal-ca"
  }

  @{
    'docker-compose.override.yml' = 'docker-compose.override.yml'

    'nginxhttps/https_entrypoint.sh' = 'tmp/local-nginxhttps/https_entrypoint.sh'
    'nginxhttps/emptyfile' = 'tmp/local-nginxhttps/ssl/emptyfile'
    'nginxhttps/nginx.conf.template' = 'tmp/local-nginxhttps/nginx.conf.template'
    'internal-ca.pem' = 'tmp/local-nginxhttps/internal-ca.pem'
    'internal-ca.crt' = 'tmp/local-nginxhttps/internal-ca.crt'

    'runtask-service/server.rb' = 'tmp/local-runtask/server.rb'
  }.GetEnumerator() | ForEach-Object {
    $LocalFilePath = $_.Key
    $DestFilePath = $_.Value

    $LocalFilePath = Join-Path (Join-Path $PSScriptRoot 'atlas') $LocalFilePath
    $LocalFile = Get-ChildItem -Path $LocalFilePath

    $DestFilePath = Join-Path $CurrentDir $DestFilePath
    $DestFile = $null
    if (Test-Path $DestFilePath) { $DestFile = Get-ChildItem -Path $DestFilePath }

    if (($null -eq $DestFile) -or ($DestFile.Length -ne $LocalFile.Length)) {
      Write-Host "Updating $DestFilePath ..." -Foreground Magenta

      $Parent = Split-Path $DestFilePath -Parent
      if (-Not (Test-Path $Parent)) { New-Item -Path $parent -ItemType Directory | Out-Null }

      Copy-Item -Path $LocalFilePath -Destination $DestFilePath -Force -Confirm:$false | Out-Null
    }
  }
  return
}

Write-Host "Inspect tfe_local_atlas container..." -Foreground Yellow
$AtlasContainer = (& docker inspect tfe_local_atlas) | ConvertFrom-JSON -AsHash
$AtlasContainerId = $AtlasContainer.Id

if (-not $AtlasContainer['State']['Running']) {
  Write-Host "Atlas Container is not running" -Foreground Red
  Exit 1
}

if (($Global:AtlasCachedContainerId -ne $AtlasContainerId) -or ($null -eq $Global:AtlasCachedEnvVar) -or $Force.IsPresent) {
  $EnvVars = @{}

  $AtlasHostName = $AtlasContainer.Config.Env | Where-Object { $_.StartsWith('TFE_FQDN=') } | Select -First 1 | ForEach-Object { Write-Output ($_ -split '=',2)[1] }
  if ([String]::IsNullOrEmpty($AtlasHostName)) {
    Write-Host "Could not determin the Atlas hostname from the container environment variables" -Foreground Red
    exit 1
  }
  Write-Verbose "Atlas is using Hostname $AtlasHostName"

  # Pre-populate needed ENV vars for Atlas config
  # The network aliases will be substituted later
  $EnvVars['ARCHIVIST_INTERNAL_URL'] = 'http://archivist.tfe:7675'
  $EnvVars['BILLING_BASE_URL'] = 'http://billing.tfe'
  $EnvVars['ISOLATION_NOMAD_BASE_URL'] = 'http://nomad.tfe:4646'
  $EnvVars['NOMAD_BASE_URL'] = 'http://nomad.tfe:4646'
  $EnvVars['QUEUE_MANAGER_BASE_URL'] = 'http://tqm.tfe:7676'
  $EnvVars['REDIS_CACHE_URL'] = 'redis://redis-cache.tfe:6379'
  $EnvVars['REDIS_URL'] = 'redis://redis.tfe:6379'
  $EnvVars['REGISTRY_BASE_URL'] = 'http://registry.tfe:3121'
  $EnvVars['SLUGINGRESS_BASE_URL'] = 'http://slugingress.tfe:7586'
  $EnvVars['TERRAFORM_STATE_PARSER_BASE_URL'] = 'http://tsp.tfe:7588'
  $EnvVars['VAULT_ADDR'] = 'http://vault.tfe:8200'
  $EnvVars['VCS_BASE_URL'] = 'http://vcs.tfe:7678'
  $EnvVars['OUTBOUND_HTTP_PROXY_HOST'] = "outbound-http-proxy"
  $EnvVars['OUTBOUND_HTTP_PROXY_PORT'] = "outbound-http-proxy"

  # Extract the Atlas Container env vars...
  $AtlasContainer['Config']['Env'] | ForEach-Object {
    $Arr = $_ -Split '=',2
    $EnvName = $Arr[0]
    $EnvVal = $Arr[1]

    # Strip ones we don't want
    Switch -regex ($EnvName) {
      '(PATH|LANG)' { break }
      '(RUBY_.+|BUNDLE_.+|GEM_.+)' { break }
      'SSH_AUTH_SOCK' { break }
      Default {
        $EnvVars[$EnvName] = $EnvVal
      }
    }
  }

  # Find all the networking information...
  # Default alias for localhost
  $NetworkAliases = [ordered]@{
    'host.docker.internal' = 'localhost'
  }

  $NetworkName = $AtlasContainer['HostConfig']['NetworkMode']
  Write-Host "Inspecting the $NetworkName network..." -Foreground Yellow
  $NetworkInfo = (& docker network inspect $NetworkName) | ConvertFrom-JSON -AsHash

  $NetworkInfo['Containers'].Keys | ForEach-Object {
    $ContainerId = $_

    Write-Host "Inspecting the $ContainerId container..." -Foreground Yellow
    $ContInfo = (& docker inspect $ContainerId) | ConvertFrom-JSON -AsHash

    Write-Host "Finding port bindings for $($ContInfo.Name)..." -Foreground Yellow
    $portBinding = $null
    $ContInfo['HostConfig']['PortBindings'].GetEnumerator() | ForEach-Object {
      if ($null -ne $_.Value) {
        $_.Value | ForEach-Object {
          if ($null -ne $_['HostPort']) {
            $portBinding = [int]$_['HostPort']
            Write-Host "Found a port binding for $portBinding" -Foreground Yellow
          }
        }
      }
    }

    if ($null -ne $portBinding) {
      Write-Host "Finding network alias for $($ContInfo.Name)..." -Foreground Yellow
      $ContNetwork = $ContInfo['NetworkSettings']['Networks'][$NetworkName]
      if ($null -eq $ContNetwork) {
        Write-Host "$($ContInfo.Name) is not on the same network as Atlas" -Foreground Yellow
      } else {
        $ContNetwork.Aliases | Where-Object { $_ -ne ''} | ForEach-Object {
          # We only care about aliases that kinda sorta look like DNS names.
          if (($_ -like '*.*') -and ($_ -ne $AtlasHostName)) {
            Write-Host "Found network alias of $_" -Foreground Yellow
            $NetworkAliases[$_] = "localhost:$portBinding"
          } else {
            Write-Host "Ignoring network alias of $_"
          }
        }
      }
    } else {
      Write-Host "$($ContInfo.Name) has no external port bindings" -Foreground Yellow
    }
  }

  # The list needs to be ordered so that entries like 'redis.tfe' getting resolved before 'redis'
  $NetworkAliasKeys = $NetworkAliases.Keys | Sort-Object { $_.Length } -Descending

  # Munge the Env Vars with network alias information
  $EnvVars.Keys.Clone() | ForEach-Object {
    $EnvName = $_
    $EnvValue = $EnvVars[$EnvName]

    $NewValue = $EnvValue
    $NetworkAliasKeys | ForEach-Object {
      $Text = [Regex]::Escape($_)
      $ReplaceText = $NetworkAliases[$_]
      if ($EnvName -like '*_HOST') { $ReplaceText = ($NetworkAliases[$_] -split ':')[0] }
      if ($EnvName -like '*_PORT') { $ReplaceText = ($NetworkAliases[$_] -split ':')[1] }

      $NewValue = $NewValue -replace "($Text`:[\d]+|$Text(?!:\/\/))", $ReplaceText
    }

    if ($NewValue -ne $EnvValue) {
      Write-host "Munging $EnvValue to $NewValue in $EnvName" -Foreground Yellow
      $EnvVars[$EnvName] = $NewValue
    }
  }

  $Global:AtlasCachedEnvVar = $EnvVars
  $Global:AtlasCachedContainerId = $AtlasContainerId
  $global:AtlasCachedFQDN = $AtlasHostName
  $Global:AtlasCachedHostIP = & ifconfig -l | xargs -n1 ipconfig getifaddr
}

# Set the Environment
$DotEnv = Join-Path $CurrentDir '.env'
$Content = ""
$Global:AtlasCachedEnvVar.GetEnumerator() | % {
  Write-Verbose "Setting $($_.Key) = $($_.Value)"
  $Content += "$($_.Key)=$($_.Value)`n"
}
$Content | Out-File -Path $DotEnv -Encoding 'utf8' -Force -Confirm:$false

# bundle exec rails server --binding 0.0.0.0 --port 3000
$RunArgs = @('bundle', 'exec', 'rails', 'server', '--binding', '0.0.0.0', '--port', '3000')
if ($args.length -gt 0) {
  $RunArgs = $args
}

$DotEnvWrapper = Join-Path $PSScriptRoot 'atlas/dotenv.rb'
Write-Host "------------------------" -Foreground Green
Write-Host "Remember to set $($global:AtlasCachedFQDN) to $($Global:AtlasCachedHostIP) in hosts file" -Foreground Green
Write-Host "------------------------" -Foreground Green

If ($PSCmdlet.ShouldProcess("Console", "Run Ruby with; $RunArgs")){
  & ruby $DotEnvWrapper @RunArgs
}
