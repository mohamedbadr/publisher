#Note: in iwndows services start: Windows Remote Management (WinRM) service 

#. $PSScriptRoot\functions.ps1

#fixed variables
$remoteRepositoryUrl = "https://Twaijrigcs@dev.azure.com/Twaijrigcs/Wafi/_git/Wafi"
$localRepositoryPath = "C:\Storage\publisher-temp"
$remoteComputer = "192.168.13.15"
$remoteApiFolder = "C:\inetpub\wwwroot\wafi-staging\wafi-api-staging"
$remoteAngularFolder = "C:\inetpub\wwwroot\wafi-staging\wafi-ng-staging"
$remoteBackupFolder = "D:\AutoPublishBackup"
$remoteUsername = "twaijri-kw\pay.server"
$remotePassword = ConvertTo-SecureString "Fmt@P@ssw0rd2019" -AsPlainText -Force
$siteName = "wafi-api-staging"



#Import-Module IISAdministration
#Import-Module $env:windir\System32\inetsrv\Microsoft.Web.Administration

#--------------------

#region check if the framework is installed
$installedSdks = & dotnet --list-sdks
$isDotNetInstalled = $false
foreach ($sdk in $installedSdks) {
    if ($sdk.StartsWith("7.") -or $sdk.StartsWith("8.")) {
        $isDotNetInstalled = $true
    }
}

if ($isDotNetInstalled -eq $false) {
    Write-Host "Please install dotnet SDK and try again." -ForegroundColor Red
    exit 1
}

#endregion

#region check if nodejs is installed
if (!(Get-Command npm -ErrorAction SilentlyContinue)) {
    Write-Host "Error: npm not found. Please install Node.js first." -ForegroundColor Red
    exit 1
}

#endregion

#region check if the remote server is reachable
try {
    $isHostFound = $false
    $availableHosts = Get-Item WSMan:\localhost\Client\TrustedHosts
    foreach ($ahost in $availableHosts) {
        if ($ahost.Value -eq $remoteComputer) {
            $isHostFound = $true
        }
    }

    if ($isHostFound -eq $false) {
        Write-Host "Adding the remote host to trusted list." -ForegroundColor Cyan
        Set-Item WSMan:\localhost\Client\TrustedHosts -Value $remoteComputer -Concatenate
        Write-Host "Remote host has been added to the trusted list successfully." -ForegroundColor Cyan
    }
}
catch {
    Write-Host "Failed to add the remote host to the trusted list" -ForegroundColor Red
    Write-Host "$($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

#endregion

# read user inputs
$brnachName = Read-Host "Enter remote branch name"
$publishApi = Read-Host "Do you want to publish the API? (y/n)"
$publishAngular = Read-Host "Do you want to publish the Angular client? (y/n)"


#region Delete existing local repository

if (Test-Path -Path $localRepositoryPath) {
    Write-Host "Deleting existing local repository..." -ForegroundColor Cyan
    Remove-Item -LiteralPath $localRepositoryPath -Force -Recurse
    Write-Host "Deleted process completed successfully" -ForegroundColor Green
}

#endregion


#region clone remote repository
Write-Host "Start cloning the remote repository..." -ForegroundColor Cyan
git clone --branch $brnachName $remoteRepositoryUrl $localRepositoryPath

if (-not $?) {
    Write-Error "Failed to clone the repository"
    exit 1
}

Write-Host "Repository has been cloned successfully" -ForegroundColor Green
#endregion


#region build the application
if ($publishApi -eq "y") {
    try {
        Write-Host "Start building the API..." -ForegroundColor Cyan
        dotnet publish  $localRepositoryPath"\src\Wafi.Web\Wafi.Web.csproj" --configuration production --output $localRepositoryPath"\api-publish"
        Write-Host "API has been built successfully" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to build the API" -ForegroundColor Red
        Write-Host "$($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

#endregion

#--------------------

# todo: check if db migration is needed

#--------------------

#region build angular application
if ($publishAngular -eq "y") {
    try {
        Write-Host "Building angular client app..." -ForegroundColor Cyan
        Set-Location $localRepositoryPath"\src\Wafi.Client"
        npm install --force
        if ($LASTEXITCODE -eq 0) {
            npm run build
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Angular client app has been built successfully" -ForegroundColor Green
            }
        }
    }
    catch {
        Write-Host "Failed to build angular client app" -ForegroundColor Red
        Write-Host "$($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }  
}
#endregion



#region open session to the server
$session = New-PSSession -ComputerName $remoteComputer -Credential (New-Object System.Management.Automation.PSCredential $remoteUsername, $remotePassword)

if ($null -eq $session) {
    Write-Host "Error: Failed to create session with remote computer."
    exit 1
}
#endregion



#region backup the current build on the production server

$apiBackupSuccess = $false
$ngBackupSuccess = $false

try {
    $currentDateTime = Get-Date
    $timestamp = $currentDateTime.ToString("ddMMyyyyHHmmss");

    if ($publishApi -eq "y") {

        Stop-Site -Session $session -SiteName $siteName
        Write-Host "Start API backup..." -ForegroundColor Cyan
        $zipPath = $remoteBackupFolder + "\api\" + $timestamp + ".zip"
        $apiBackupSuccess = Zip -OutputPath $zipPath -InputPath $remoteApiFolder
        Write-Host "Api has been backedup successfully" -ForegroundColor Green
    }
    
    if ($publishAngular -eq "y") {
        Write-Host "Start Angular backup..." -ForegroundColor Cyan
        $zipPath = $remoteBackupFolder + "\ng\" + $timestamp + ".zip"
        $ngBackupSuccess = Zip -OutputPath $zipPath -InputPath $remoteAngularFolder
        Write-Host "Angular has been backedup successfully" -ForegroundColor Green
    }

    if ($publishApi -eq "y" -and $apiBackupSuccess -eq $false) {
        Write-Host "Failed to backup the current build on the production server" -ForegroundColor Red
        Remove-PSSession $session
        exit 1
    }

    if ($publishAngular -eq "y" -and $ngBackupSuccess -eq $false) {
        Write-Host "Failed to backup the current build on the production server" -ForegroundColor Red
        Remove-PSSession $session
        exit 1
    }

    Write-Host "Completed backup process" -ForegroundColor Green
}
catch {
    Write-Host "Failed to backup" -ForegroundColor Red
    Write-Host "$($_.Exception.Message)" -ForegroundColor Red
    Remove-PSSession $session
    exit 1
}

#endregion


#region copy the application to the production server
try {
    if ($publishApi -eq "y") {
        $childItems = Get-ChildItem -Path $localRepositoryPath"\api-publish"
        Write-Host "Copy the API to the server" -ForegroundColor Cyan
        Copy-Item -Path $childItems.FullName -Destination $remoteApiFolder"\" -ToSession $session -Recurse -Verbose
        Write-Host "Api has been copied successfully" -ForegroundColor Green

        Start-Site -Session $session -SiteName $siteName
    }

    if ($publishAngular -eq "y") {
        $childItems = Get-ChildItem -Path $localRepositoryPath"\src\Wafi.Client\dist"
        Write-Host "Copy the Angular client to the server" -ForegroundColor Cyan
        Remove-RemoteFolder -Folder $remoteAngularFolder -Session $session
        Copy-Item -Path $childItems.FullName -Destination $remoteAngularFolder"\" -ToSession $session -Recurse -Verbose
        Write-Host "Angular client has been copied successfully" -ForegroundColor Green
    }
   
}
catch {
    Write-Host "Failed to copy the application to the production server" -ForegroundColor Red
    Write-Host "$($_.Exception.Message)" -ForegroundColor Red
    Remove-PSSession $session
    exit 1
}

#endregion copy the build to the production server


# delete local source code and publish folders
Remove-PSSession $session
Remove-Item -LiteralPath $localRepositoryPath -Force -Recurse






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
        [string]$ComputerName,
        [string]$Folder
    )

    try {
        $scriptBlock = {
            param ($folderPath)
            if (Test-Path -Path $folderPath) {
                Get-ChildItem -Path $Folder -Recurse | Remove-Item -Force -Recurse
                Write-Output "The folder contents have been deleted, but the folder has been kept."
            } else {
                Write-Output "The specified folder does not exist."
            }
        }
        
        # Execute the script block on the remote computer
        Invoke-Command -ComputerName $ComputerName -ScriptBlock $scriptBlock -ArgumentList $Folder
    }
    catch {
        Write-Host "$($_.Exception.Message)" -ForegroundColor Red
        exit 0
    }

   
}
#endregion