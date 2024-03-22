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
    Write-Host "Please install dotnet $dotNetVersion and try again." -ForegroundColor Red
    return
}

if (!(Get-Command npm -ErrorAction SilentlyContinue)) {
    Write-Host "Error: npm not found. Please install Node.js first." -ForegroundColor Red
    return;
}

#--------------------

# ask user for the branch name
$brnachName = Read-Host "Enter remote branch name"

#--------------------

# clone remote repository
try {
    Write-Host "Start cloning the remote repository..." -ForegroundColor Cyan
    git clone --branch $brnachName $remoteRepositoryUrl $localRepositoryPath
    Write-Host "Repository has been cloned successfully" -ForegroundColor Cyan
}
catch {
    Write-Host "Failed to clone the repository" -ForegroundColor Red
    return
}


#--------------------

# build the application
try {
    Write-Host "Start building the API..." -ForegroundColor Cyan
    dotnet publish  $localRepositoryPath"\src\Wafi.Web\Wafi.Web.csproj" --configuration production --output $localRepositoryPath"\api-publish"
    Write-Host "API has been built successfully" -ForegroundColor Cyan
}
catch {
    Write-Host "Failed to build the API" -ForegroundColor Red
    return
}


#--------------------

# todo: check if db migration is needed

#--------------------

# build angular application
try {
    Write-Host "Building angular client app..." -ForegroundColor Cyan
    Set-Location $localRepositoryPath"\src\Wafi.Client"
    npm install --force
    if ($LASTEXITCODE -eq 0) {
        npm run build
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Angular client app has been built successfully" -ForegroundColor Cyan
        }
    }
}
catch {
    Write-Host "Failed to build angular client app" -ForegroundColor Red
    Write-Host "$($_.Exception.Message)" -ForegroundColor Red
    return
}


# backup the current build on the production server

# copy the application to the production server

# copy the build to the production server

# delete local source code and publish folders

