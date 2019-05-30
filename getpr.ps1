[CmdletBinding(DefaultParameterSetName='interactive')]
param(
  [Parameter(Mandatory = $true, ParameterSetName = "uri")]
  [Alias("uri", "github")]
  [ValidateNotNullOrEmpty()]
  [String] $GithubURI,

  [Parameter(Mandatory = $false, ParameterSetName = "interactive")]
  [String] $Owner = '',

  [Parameter(Mandatory = $false, ParameterSetName = "interactive")]
  [String] $Project = '',

  [Parameter(Mandatory = $false, ParameterSetName = "interactive")]
  [Int] $PullRequest = -1
)

$CurrentDir = (Get-Location).Path

switch ($PsCmdlet.ParameterSetName) {
  'uri' {
    $arrURI = $GithubURI -split '/'

    $Owner = $arrURI[3]
    $Project = $arrURI[4]
    $PullRequest = [Int]$arrURI[6]

  }
  'interactive' {
    if ($Owner -eq '')       { $Owner = Read-Host -Prompt "Enter the project owner" }
    if ($Project -eq '')     { $Project = Read-Host -Prompt "Enter the project name" }
    if ($PullRequest -eq -1) { $PullRequest = Read-Host -Prompt "Enter the PR number" }
  }
}

# Get the base branch
Write-Verbose "Attempting to the get PR information at https://api.github.com/repos/$Owner/$Project/pulls/$PullRequest"
$PRInfo = Invoke-RestMethod -URI "https://api.github.com/repos/$Owner/$Project/pulls/$PullRequest" -ErrorAction Stop
$Branch = $PRInfo.base.ref

Write-Verbose "PR Owner = $Owner"
Write-Verbose "PR Project = $Project"
Write-Verbose "PR Branch = $Branch"
Write-Verbose "PR Number = $PullRequest"

$TargetDir = Join-Path -Path $CurrentDir -ChildPath "$Project-pr$PullRequest"
if (Test-Path -Path $TargetDir) { Remove-Item -Path $TargetDir -Recurse -Force -Confirm:$false | Out-Null }

Write-Verbose "Cloning..."
& git clone "https://github.com/$Owner/$Project.git" $TargetDir

Push-Location $TargetDir

Write-Verbose "Fetching PR..."
& git fetch origin "refs/pull/$PullRequest/head:pr_$PullRequest"

Write-Verbose "Changing to intended branch..."
& git checkout $Branch

Write-Verbose "Merging PR..."
& git merge "pr_$PullRequest" --no-ff

Pop-Location
