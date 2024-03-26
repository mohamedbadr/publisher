$sevenZipPath = "C:\Program Files\7-Zip\7z.exe"

function Stop-Site{
    param(
        [System.Management.Automation.Runspaces.PSSession]$Session,
        [string]$SiteName
    )

    Write-Host "Stop the API site" -ForegroundColor Cyan
    $stop = { Stop-WebSite $args[0] }; 
    Invoke-Command -Session $Session -ScriptBlock $stop -ArgumentList $SiteName
    Write-Host "API site stopped successfully" -ForegroundColor Green
}

function Zip{
    param(
        [string]$OutputPath,
        [string]$InputPath
    )
    $scriptBlock = {
        param($sevenZipPath, $outputZipFile, $remoteApiFolder)
        & $sevenZipPath a -mx=9 -tzip $outputZipFile $remoteApiFolder
    }

    Invoke-Command -Session $session -ScriptBlock $scriptBlock `
        -ArgumentList $sevenZipPath ,$OutputPath, $InputPath
}

function Backup-RemoteFolder{
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

}