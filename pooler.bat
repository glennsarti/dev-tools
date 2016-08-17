@ECHO OFF

powershell "& { Import-Module 'C:\Source\posh-vmpool\src\functions\module.psm1'; Start-VMPoolerUI -URL 'https://vmpooler.delivery.puppetlabs.net/api/v1' -Verbose }"