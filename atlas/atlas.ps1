param([Switch]$Force)

Write-Host "Inspect tfe_local_atlas container..." -Foreground Yellow
$AtlasContainer = (& docker inspect tfe_local_atlas) | ConvertFrom-JSON -AsHash
$AtlasContainerId = $AtlasContainer.Id

if (($Global:AtlasCachedContainerId -ne $AtlasContainerId) -or ($null -eq $Global:AtlasCachedEnvVar) -or $Force.IsPresent) {
  $EnvVars = @{}

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
        #Write-Host "Using $EnvVal..."
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
        $ContNetwork.Aliases | ForEach-Object {
          Write-Host "Found network alias of $_" -Foreground Yellow
          $NetworkAliases[$_] = "localhost:$portBinding"
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
      $NewValue = $NewValue -replace "($Text`:[\d]+|$Text(?!:\/\/))", $NetworkAliases[$_]
    }

    if ($NewValue -ne $EnvValue) {
      Write-host "Munging $EnvValue to $NewValue in $EnvName" -Foreground Yellow
      $EnvVars[$EnvName] = $NewValue
    }
  }

  $Global:AtlasCachedEnvVar = $EnvVars
  $Global:AtlasCachedContainerId = $AtlasContainerId
}

# Set the Environment
$Global:AtlasCachedEnvVar.GetEnumerator() | % {
  Write-Verbose "Setting $($_.Key) = $($_.Value)"
  Set-Item -Path "Env:$($_.Key)" -Value $_.Value
}

Write-Host "Atlas is configured!" -Foreground Green

$RunArgs = @('bundle', 'exec', 'rails', 'server', '--binding', '0.0.0.0', '--port', '3000')
if ($args.length -gt 0) {
  $RunArgs = $args
}

$Cmd, $OtherArgs = $RunArgs
& $Cmd @OtherArgs
