param(
  #[switch]$EnableJobs,
  [switch]$DeleteJobs,
  [String]$FilterJobs = '.+'
)
$ErrorActionPreference = 'Stop'

Import-Module Jenkins

$JenkinsURI = 'https://jenkins-master-prod-1.delivery.puppetlabs.net'
$ExperimentalRegEx = '^experimental_auto_puppetlabs-'

if ($DeleteJobs) {
  $Credential = Get-Credential -UserName 'glenn.sarti' -Message "Password for $JenkinsURI"

  Get-JenkinsJobList -Uri $JenkinsURI |
    ? { $_.name -match $ExperimentalRegEx } |
    ? { $_.name -match $FilterJobs } |
    % {
      $JobName = $_.name

      Write-Progress -Activity "Deleting Experimental Jobs" -CurrentOperation "Deleting $JobName"
      Remove-JenkinsJob -Uri $JenkinsURI -Credential $Credential -Name $JobName -Confirm:$false
    }

}

Get-JenkinsJobList -Uri $JenkinsURI |
  ? { $_.name -match $ExperimentalRegEx } |
  ? { $_.name -match $FilterJobs } |
  ft -Property name
