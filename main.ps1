#fixed variables
$remoteRepositoryUrl = "https://Twaijrigcs@dev.azure.com/Twaijrigcs/Wafi/_git/Wafi"
$localRepositoryPath = "C:\Storage\publisher-temp"
$dotNetVersion = "7."

#--------------------

# check if the framework is installed
$installedSdks = & dotnet --list-sdks
$isDotNetInstalled = $false
foreach ($sdk in $installedSdks) {
    if ($sdk.StartsWith($dotNetVersion)) {
        $isDotNetInstalled = $true
    }
}

if ($isDotNetInstalled -eq $false) {
    Write-Host "Please install dotnet $dotNetVersion and try again."
    return
}

#--------------------

# ask user for the branch name
$brnachName = Read-Host "Enter remote branch name"

#--------------------

# clone remote repository
Write-Host "Start cloning the remote repository..."
git clone --branch $brnachName $remoteRepositoryUrl $localRepositoryPath
Write-Host "Repository has been cloned successfully"

#--------------------

# restore nuget packages
Write-Host "Starting Package Restore..."
dotnet restore $localRepositoryPath"\Wafi.sln"
Write-Host "Package Restore has been completed successfully"

#--------------------

# build the application

# check if db migration is needed

#--------------------

# build angular application
Write-Host "Building angular client app..."
Start-Process -FilePath (Get-Location).path"\ng-build.bat" -ArgumentList $localRepositoryPath"\src\Wafi.Client" -Wait
Write-Host "Angular client app has been built successfully"

# backup the current build on the production server

# copy the application to the production server

# copy the build to the production server

# delete local source code and publish folders

