
$session = New-PSSession -ComputerName $remoteComputer -Credential (New-Object System.Management.Automation.PSCredential $remoteUsername, $remotePassword)

if ($null -eq $session) {
    Write-Host "Error: Failed to create session with remote computer."
    return
}



try {

    $currentDateTime = Get-Date
    $timestamp = $currentDateTime.ToString("ddMMyyyyHHmmss");
    

    if ($publishApi -eq "y") {

        Write-Host "Stop the API site" -ForegroundColor Cyan
        $stop = { Stop-WebSite $args[0] };  
        Invoke-Command -Session $session -ScriptBlock $stop -ArgumentList $siteName 
        Write-Host "API site stopped successfully" -ForegroundColor Green

        Write-Host "Zipping current version before backup..." -ForegroundColor Cyan

        $zipPath = $remoteApiFolder+"\"+$timestamp+".zip"
        
        $scriptBlock = {
            param($sevenZipPath, $outputZipFile, $remoteApiFolder)
            & "$sevenZipPath" a -tzip "$outputZipFile" "$remoteApiFolder"
        }
        Invoke-Command -Session $session -ScriptBlock $scriptBlock -ArgumentList $sevenZipPath ,$zipPath, $remoteApiFolder




        Write-Host "Start API backup..." -ForegroundColor Cyan

        Write-Host "Copying to a local folder..." -ForegroundColor Cyan
        Copy-Item -Path $remoteApiFolder\$timestamp.zip -Destination $localRepositoryPath"\temp" -FromSession $session -Verbose -Recurse
        Write-Host "do backup on the server ..." -ForegroundColor Cyan
        $remoteApiBackupFolder = "D:\AutoPublishBackup\\api\" + $timestamp
        Copy-Item -Path $localRepositoryPath"\temp" -Destination $remoteApiBackupFolder -ToSession $TargetSession -Verbose -Recurse
        
        Write-Host "deleting local temp folder..." -ForegroundColor Cyan
        Remove-Item -LiteralPath $localRepositoryPath"\temp" -Force -Recurse

    }
    
    if ($publishAngular -eq "y") {
        $remoteAngularBackupFolder = $remoteBackupFolder + "\ng\" + $timestamp
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
