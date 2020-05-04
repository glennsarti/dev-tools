@ECHO OFF

start powershell "& { Import-Module 'C:\Source\posh-vmpool\PSVMPooler\PSVMPooler.psm1'; Start-VMPoolerUI -URL 'http://localhost:4567/api/v1' -Credential (Get-Credential 'glenn.sarti') -Verbose }"