@ECHO OFF

start powershell "& { Import-Module 'C:\Source\posh-vmpool\PSVMPooler\PSVMPooler.psm1'; Start-VMPoolerUI -URL 'http://vmpooler.delivery.puppetlabs.net/api/v1' -Verbose }"