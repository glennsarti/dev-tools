$script:GithubToken = $ENV:GITHUB_TOKEN
$script:GithubUsername = $ENV:GITHUB_USERNAME

Function Invoke-GithubAPI {
  [CmdletBinding()]

  Param(
    [Parameter(Mandatory = $True, ParameterSetName = 'RelativeURI')]
    [String]$RelativeUri,

    [Parameter(Mandatory = $True, ParameterSetName = 'AbsoluteURI')]
    [String]$AbsoluteUri,

    [Parameter(Mandatory = $False)]
    [switch]$Raw,

    [String]$Method = 'GET',

    [Object]$Body = $null
  )

  if ($PsCmdlet.ParameterSetName -eq 'RelativeURI') {
    $uri = "https://api.github.com" + $RelativeUri
  }
  else {
    $uri = $AbsoluteUri
  }

  $result = ""

  $oldPreference = $ProgressPreference

  $auth = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($script:GithubUsername + ':' + $script:GithubToken));

  $ProgressPreference = 'SilentlyContinue'
  $Headers = @{
    'Accept'        = 'application/vnd.github.inertia-preview+json' # Needed for project API
    'Authorization' = $auth;
  }
  $splat = @{
    'Uri'             = $uri
    'UseBasicParsing' = $True
    'Headers'         = $Headers
    'Method'          = $Method
  }
  if ($null -ne $Body) { $splat['Body'] = ConvertTo-Json $Body -Compress }
  try {
    $result = Invoke-WebRequest @splat -ErrorAction 'Stop'
  } catch {
    Write-Verbose "Invoke-WebRequest arguments were $($splat | ConvertTo-JSON -Depth 10)"
    Throw $_
  }
  $ProgressPreference = $oldPreference

  if ($Raw) {
    Write-Output $result
  }
  else {
    Write-Output $result.Content | ConvertFrom-JSON
  }
}

# Function Invoke-GithubAPIWithPaging($RelativeUri) {
#   $response = Invoke-GithubAPI -RelativeUri $RelativeUri -Raw
#   $result = $response.Content | ConvertFrom-Json
#   if (!($result -is [Array])) { $result = @($result) }
#   $nextLink = $response.RelationLink.next
#   do {
#     if ($null -ne $nextLink) {
#       $response = Invoke-GithubAPI -AbsoluteUri $nextLink -Raw
#       $result = $result + ($response.Content | ConvertFrom-Json)
#       $nextLink = $response.RelationLink.next
#     }
#   }
#   while ($null -ne $nextLink)

#   Write-Output $result
# }

$watchedRepos = Invoke-GithubAPI -RelativeUri '/user/subscriptions'

$watchedRepos | ? { $_.owner.login -eq 'puppetlabs' } | ? { @('puppet-vscode', 'puppet-editor-services', 'puppet-editor-syntax') -notcontains $_.name } | % {
  Write-Host "Deleting subscription $($_.name)"

  Invoke-GithubAPI -RelativeUri "/repos/puppetlabs/$($_.name)/subscription" -Method 'DELETE'
}
