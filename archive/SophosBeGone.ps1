$ServiceList = Get-Service | Where-Object { $_.DisplayName -like '*Sophos*' }
$ServiceList += Get-Service -Include "hmpalertsvc"

$ServiceList | ForEach-Object {
  $Service = $_

  if ($Service.Status -eq 'Running') {
    Write-Host "Stopping '$($Service.Name)' ..."
    Stop-Service $Service -Confirm:$False -Force -NoWait -ErrorAction Continue
  }
}
