$remoteRepositoryUrl = "git@ssh.dev.azure.com:v3/Twaijrigcs/Wafi/Wafi"
$localRepositoryPath = "C:\Storage\publisher-temp"
$brnachName = "develop"


Clone-Repo | Build-Repo 
Complete-Repo


function Clone-Repo {
    Get-Service -Name ssh-agent
    Set-Service ssh-agent -StartupType Manual
    Start-Service ssh-agent
    ssh-add ./od_rsa
    git clone --branch $brnachName $remoteRepositoryUrl $localRepositoryPath

    if ($LASTEXITCODE -eq 0) {
        Write-Output $true
    }
    else {
        Write-Output $false
    }
}

function Build-Repo {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)] $check)
    
    if ($check -eq $true) {
        Write-Host "Building repository..........."
    }
    else {
        Write-Host "Failed to clone repository xxxxxxxxxxxxxxxxxx"
        exit 1
    }

}

function Complete-Repo {
    Write-Host "Completing repository..........."
}