##1 run on the server as administrator
#Import-Module ServerManager
#Add-WindowsFeature Web-Scripting-Tools

##2 how to call after preparing from the step 1 (no need it's already included in the main script), it's here for test purpose
Import-Module WebAdministration
Stop-Website "wafi-api-staging"
Start-Website "wafi-api-staging"


#Install-Module ps2exe
#Invoke-PS2EXE J:\Code\publisher\test.ps1 J:\Code\publisher\test.exe


Enable-PSRemoting –Force
