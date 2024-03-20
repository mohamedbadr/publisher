#fixed variables
$remoteRepositoryUrl = "https://Twaijrigcs@dev.azure.com/Twaijrigcs/Wafi/_git/Wafi"
$localRepositoryPath = "C:\Storage\publisher-temp"

# ask user for the branch name
$brnachName = Read-Host "Enter remote branch name"

# clone remote repository
Write-Host "Start cloning the remote repository..."
git clone --branch $brnachName $remoteRepositoryUrl $localRepositoryPath
Write-Host "Repository has been cloned successfully"

# check if dn migration is needed

# build the application

# build angular application

# backup the current build on the production server

# copy the application to the production server

# copy the build to the production server

# delete local source code and publish folders

