param($Command = '/bin/bash')
$Containers = (&docker ps --format '{{.ID}}')

if ($Containers.GetType().ToString() -ne 'System.String') { Throw "There are either no containers, or more than one container running" }

& docker exec -it $Containers $Command
