#Note: in iwndows services start: Windows Remote Management (WinRM) service 

. .\functions.ps1

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
    exit 1
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
    exit 1
}

#--------------------

# ask user for the branch name
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

$backupSuccess = $false
try {
    $currentDateTime = Get-Date
    $timestamp = $currentDateTime.ToString("ddMMyyyyHHmmss");

    if ($publishApi -eq "y") {

       Stop-Site -Session $session -SiteName $siteName

        Write-Host "Start API backup..." -ForegroundColor Cyan

        Write-Host "Zipping current version before backup..." -ForegroundColor Cyan
        $zipPath = $remoteApiFolder + "\" + $timestamp + ".zip"
        Zip -OutputPath $zipPath -InputPath $remoteApiFolder

        Write-Host "Copying to a local folder..." -ForegroundColor Cyan
        Copy-Item -Path $remoteApiFolder\$timestamp.zip -Destination $localRepositoryPath"\temp" -FromSession $session -Verbose -Recurse
        Write-Host "do backup on the server ..." -ForegroundColor Cyan
        $remoteApiBackupFolder = "D:\AutoPublishBackup\api\" + $timestamp
        Copy-Item -Path $localRepositoryPath"\temp" -Destination $remoteApiBackupFolder -ToSession $session -Verbose -Recurse
        
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
    exit 1
}


if ($backupSuccess -eq $false) {
    Remove-PSSession $session
    Write-Host "Failed to backup the current build on the production server" -ForegroundColor Red
    exit 1
}

#endregion

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
    exit 1
}

# copy the build to the production server




# delete local source code and publish folders
Remove-PSSession $session