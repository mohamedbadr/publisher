#. $PSScriptRoot\functions.ps1
. .\functions.ps1

#fixed variables
$remoteRepositoryUrl = "https://Twaijrigcs@dev.azure.com/Twaijrigcs/Wafi/_git/Wafi"
$localRepositoryPath = "C:\Storage\publisher-temp"
$remoteComputer = "192.168.13.15"
$remoteApiFolder = "C:\inetpub\wwwroot\wafi-staging\wafi-api-staging"
$remoteBackupFolder = "D:\AutoPublishBackup"
$remoteUsername = "twaijri-kw\pay.server"
$remotePassword = ConvertTo-SecureString "Fmt@P@ssw0rd2019" -AsPlainText -Force
$siteName = "wafi-api-staging"
$remoteAngularFolder = "C:\inetpub\wwwroot\wafi-staging\wafi-ng-staging"


$publishAngular = "y"

#region open session to the server
$session = New-PSSession -ComputerName $remoteComputer -Credential (New-Object System.Management.Automation.PSCredential $remoteUsername, $remotePassword)

if ($null -eq $session) {
    Write-Host "Error: Failed to create session with remote computer."
    exit 1
}
#endregion


if ($publishAngular -eq "y") {
    $childItems = Get-ChildItem -Path $localRepositoryPath"\src\Wafi.Client\dist"
    Write-Host "Copy the Angular client to the server" -ForegroundColor Cyan
    Remove-RemoteFolder -ComputerName $remoteComputer -Folder $remoteAngularFolder -Session $session
    #Copy-Item -Path $childItems.FullName -Destination $remoteAngularFolder"\" -ToSession $session -Recurse -Verbose
    Write-Host "Angular client has been copied successfully" -ForegroundColor Green
}
 