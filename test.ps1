

#fixed variables
$remoteRepositoryUrl = "https://Twaijrigcs@dev.azure.com/Twaijrigcs/Wafi/_git/Wafi"
$localRepositoryPath = "C:\Storage\publisher-temp"
#$dotNetVersion = "7."
$remoteComputer = "192.168.13.15"
$remoteApiFolder = "C:\inetpub\wwwroot\wafi-api-pubtest"
$remoteBackupFolder = "AutoPublishBackup"
$remoteUsername = "twaijri-kw\pay.server"
$remotePassword = ConvertTo-SecureString "Fmt@P@ssw0rd2019" -AsPlainText -Force
#--------------------

$publishApi = "y"

#-----------------------
# open session to the server
$session = New-PSSession -ComputerName $remoteComputer -Credential (New-Object System.Management.Automation.PSCredential $remoteUsername, $remotePassword)

if ($null -eq $session) {
    Write-Host "Error: Failed to create session with remote computer."
    return
}

#---------------------
# backup the current build on the production server

$backupSuccess = $false
try {
    $currentDateTime = Get-Date

    if ($publishApi -eq "y") {
        $remoteApiBackupFolder = $remoteBackupFolder + "\api\" + $currentDateTime.ToString("ddMMyyyyHHmmss")
        Write-Host "Start API backup" -ForegroundColor Cyan
        Copy-Item -Path $remoteApiFolder -Destination "\\$remoteComputer\$remoteApiBackupFolder" -Recurse -FromSession $session
    }
    
    if ($publishAngular -eq "y") {
        $remoteAngularBackupFolder = $remoteBackupFolder + "\ng\" + $currentDateTime.ToString("ddMMyyyyHHmmss")
        Write-Host "Start Angular backup" -ForegroundColor Cyan
        Copy-Item -Path $remoteApiFolder -Destination "\\$remoteComputer\$remoteAngularBackupFolder" -Recurse -FromSession $session
    }

    $backupSuccess = $true
    Write-Host "Completed backup process" -ForegroundColor Green
}
catch {
    Write-Host "Failed to backup" -ForegroundColor Red
    Write-Host "$($_.Exception.Message)" -ForegroundColor Red
    Remove-PSSession $session
    return
}


if ($backupSuccess -eq $false) {
    Remove-PSSession $session
    Write-Host "Failed to backup the current build on the production server" -ForegroundColor Red
    return
}

#---------------------
# copy the application to the production server
try {
    if ($publishApi -eq "y") {
        $childItems = Get-ChildItem -Path $localRepositoryPath"\api-publish"
        Write-Host "Copy the API to the server" -ForegroundColor Cyan
        Copy-Item -Path $childItems.FullName -Destination $remoteApiFolder"\" -ToSession $session -Recurse -Verbose
        Write-Host "ApiI has been copied successfully" -ForegroundColor Green
    }
   
}
catch {
    Write-Host "Failed to copy the application to the production server" -ForegroundColor Red
    Write-Host "$($_.Exception.Message)" -ForegroundColor Red
    Remove-PSSession $session
    return
}