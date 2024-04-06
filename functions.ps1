#region helper functions
$sevenZipPath = "C:\Program Files\7-Zip\7z.exe"

function Stop-Site {
    param(
        [System.Management.Automation.Runspaces.PSSession]$Session,
        [string]$SiteName
    )

    Write-Host "Stop the API site" -ForegroundColor Cyan
    $stop = { Stop-WebSite $args[0] }; 
    Invoke-Command -Session $Session -ScriptBlock $stop -ArgumentList $SiteName
    Write-Host "API site stopped successfully" -ForegroundColor Green
}

function Start-Site {
    param(
        [System.Management.Automation.Runspaces.PSSession]$Session,
        [string]$SiteName
    )

    Write-Host "Start the API site" -ForegroundColor Cyan
    $start = { Start-WebSite $args[0] };  
    Invoke-Command -Session $Session -ScriptBlock $start -ArgumentList $SiteName
    Write-Host "API site started successfully" -ForegroundColor Green
}

function Zip {
    param(
        [string]$OutputPath,
        [string]$InputPath
    )

    try {
        $scriptBlock = {
            param($sevenZipPath, $outputZipFile, $remoteApiFolder)
            & $sevenZipPath a -mx=9 -tzip $outputZipFile $remoteApiFolder
        }
    
        Invoke-Command -Session $session -ScriptBlock $scriptBlock `
            -ArgumentList $sevenZipPath , $OutputPath, $InputPath
    }
    catch {
        Write-Host "$($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
   
    return $true
}

function Backup-RemoteFolder {

    try {
        param(
            [string]$SourceFolder,
            [string]$DestinationFolder,
            [string]$LocalFolder,
            [System.Management.Automation.Runspaces.PSSession]$Session
        )

        Write-Host "Copying to a local folder..." -ForegroundColor Cyan
        Copy-Item -Path $SourceFolder\$TimeStamp.zip `
            -Destination $LocalFolder"\temp" `
            -FromSession $Session -Verbose -Recurse

        Write-Host "do backup on the server ..." -ForegroundColor Cyan
        Copy-Item -Path $LocalFolder -Destination $DestinationFolder -ToSession `
            $Session -Verbose -Recurse

        Write-Host "deleting local temp folder..." -ForegroundColor Cyan
        Remove-Item -LiteralPath $LocalFolder -Force -Recurse

        return $true
    }
    catch {
        return $false
    }
}

function Remove-RemoteFolder {
    param(
        [string]$Folder,
        [System.Management.Automation.Runspaces.PSSession]$Session
    )

    try {

        Write-Host "Remove the folder " $Folder "contents on the server..." -ForegroundColor Cyan

        $scriptBlock = {
            param ($folderPath)
            if (Test-Path -Path $folderPath) {
                Get-ChildItem -Path $Folder -Recurse | Remove-Item -Force -Recurse
                Write-Output "The folder contents have been deleted, but the folder has been kept."
            }
            else {
                Write-Output "The specified folder does not exist."+:$Folder
            }
        }
        
        # Execute the script block on the remote computer
        Invoke-Command -Session $session -ScriptBlock $scriptBlock -ArgumentList $Folder
    }
    catch {
        Write-Host "$($_.Exception.Message)" -ForegroundColor Red
        exit 0
    }

   
}
#endregion