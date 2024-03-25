﻿#Note: in iwndows services start: Windows Remote Management (WinRM) service 


#fixed variables
$remoteRepositoryUrl = "https://Twaijrigcs@dev.azure.com/Twaijrigcs/Wafi/_git/Wafi"
$localRepositoryPath = "C:\Storage\publisher-temp"
#$dotNetVersion = "7."
$remoteComputer = "192.168.13.15"
$remoteApiFolder = "C:\inetpub\wwwroot\wafi-staging\wafi-api-staging"
$remoteBackupFolder = "AutoPublishBackup"
$remoteUsername = "twaijri-kw\pay.server"
$remotePassword = ConvertTo-SecureString "Fmt@P@ssw0rd2019" -AsPlainText -Force
$siteName = "wafi-api-staging"
$sevenZipPath = "C:\Program Files\7-Zip\7z.exe"




#Import-Module IISAdministration
#Import-Module $env:windir\System32\inetsrv\Microsoft.Web.Administration



#--------------------

# check if the framework is installed
# $installedSdks = & dotnet --list-sdks
# $isDotNetInstalled = $false
# foreach ($sdk in $installedSdks) {
#     if ($sdk.StartsWith($dotNetVersion)) {
#         $isDotNetInstalled = $true
#     }
# }

# if ($isDotNetInstalled -eq $false) {
#     Write-Host "Please install dotnet $dotNetVersion and try again." -ForegroundColor Red
#     return
# }

if (!(Get-Command npm -ErrorAction SilentlyContinue)) {
    Write-Host "Error: npm not found. Please install Node.js first." -ForegroundColor Red
    return;
}

#--------------------

# check if the remote server is reachable
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
    return
}

#--------------------

# ask user for the branch name
$brnachName = Read-Host "Enter remote branch name"
$publishApi = Read-Host "Do you want to publish the API? (y/n)"
$publishAngular = Read-Host "Do you want to publish the Angular client? (y/n)"

#--------------------
#Delete existing local repository

if (Test-Path -Path $localRepositoryPath) {
    Write-Host "Deleting existing local repository..." -ForegroundColor Cyan
    Remove-Item -LiteralPath $localRepositoryPath -Force -Recurse
    Write-Host "Deleted process completed successfully" -ForegroundColor Green
}

#--------------------

# clone remote repository
try {
    Write-Host "Start cloning the remote repository..." -ForegroundColor Cyan
    git clone --branch $brnachName $remoteRepositoryUrl $localRepositoryPath
    Write-Host "Repository has been cloned successfully" -ForegroundColor Green
}
catch {
    Write-Host "Failed to clone the repository" -ForegroundColor Red
    Write-Host "$($_.Exception.Message)" -ForegroundColor Red
    return
}


#--------------------

# build the application
if ($publishApi -eq "y") {
    try {
        Write-Host "Start building the API..." -ForegroundColor Cyan
        dotnet publish  $localRepositoryPath"\src\Wafi.Web\Wafi.Web.csproj" --configuration production --output $localRepositoryPath"\api-publish"
        Write-Host "API has been built successfully" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to build the API" -ForegroundColor Red
        Write-Host "$($_.Exception.Message)" -ForegroundColor Red
        return
    }
}

#--------------------

# todo: check if db migration is needed

#--------------------

# build angular application
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
        return
    }  
}

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

        Write-Host "Stop the API site" -ForegroundColor Cyan
        $stop = { Stop-WebSite $args[0] };  
        Invoke-Command -Session $session -ScriptBlock $stop -ArgumentList $siteName 
        Write-Host "API site stopped successfully" -ForegroundColor Green

        Write-Host "Start API backup..." -ForegroundColor Cyan

        Write-Host "Copying to a local folder..." -ForegroundColor Cyan
        Copy-Item -Path $remoteApiFolder -Destination $localRepositoryPath"\temp" -FromSession $session -Verbose -Recurse
        Write-Host "do backup on the server ..." -ForegroundColor Cyan
        $remoteApiBackupFolder = "D:\AutoPublishBackup\\api\" + $currentDateTime.ToString("ddMMyyyyHHmmss")
        Copy-Item -Path $localRepositoryPath"\temp" -Destination $remoteApiBackupFolder -ToSession $TargetSession -Verbose -Recurse

        Write-Host "deleting local temp folder..." -ForegroundColor Cyan
        Remove-Item -LiteralPath $localRepositoryPath"\temp" -Force -Recurse
        
        # $credentials = New-Object System.Management.Automation.PSCredential($remoteUsername, $remotePassword)
        # $remoteApiBackupFolder = $remoteBackupFolder + "\api\" + $currentDateTime.ToString("ddMMyyyyHHmmss")
        # Copy-Item -Path $remoteApiFolder -Destination "\\$remoteComputer\$remoteApiBackupFolder" -Credential $credentials -Recurse -FromSession $session
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
        Write-Host "Api has been copied successfully" -ForegroundColor Green

        Write-Host "Start the API site" -ForegroundColor Cyan
        $start = { Start-WebSite $args[0] };  
        Invoke-Command -Session $session -ScriptBlock $stop -ArgumentList $siteName 
        Write-Host "API site has been started successfully" -ForegroundColor Green
    }
   
}
catch {
    Write-Host "Failed to copy the application to the production server" -ForegroundColor Red
    Write-Host "$($_.Exception.Message)" -ForegroundColor Red
    Remove-PSSession $session
    return
}

# copy the build to the production server




# delete local source code and publish folders
Remove-PSSession $session