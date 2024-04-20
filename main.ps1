#Note: in wiwndows services start: Windows Remote Management (WinRM) service 

. $PSScriptRoot\functions.ps1

#fixed variables
$remoteRepositoryUrl = "git@ssh.dev.azure.com:v3/Twaijrigcs/Wafi/Wafi"
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
$installedSdks = & dotnet --list-sdks -ErrorAction 
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

#region check if git is installed
if (!(Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "Error: git not found. Please install git first." -ForegroundColor Red
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
Get-Service -Name ssh-agent
if (-not $?) {
    Write-Error "ssh-agent service is not running. Please start the service and try again."
    exit 1
}
Set-Service ssh-agent -StartupType Manual
Start-Service ssh-agent
ssh-add ./id_rsa
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
        Remove-RemoteFolder ComputerName $remoteComputer Folder $remoteApiFolder
        Write-Host "Copy the API to the server" -ForegroundColor Cyan
        Copy-Item -Path $childItems.FullName -Destination $remoteApiFolder"\" -ToSession $session -Force -Recurse -Verbose
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