function MakeRemoteFolder($RemoteServer, $RemotePath) {
    Invoke-Command -ScriptBlock {
        param (
            [Parameter(Mandatory = $false)][string]$RemotePath
        )
        If (!(test-path $RemotePath)) {
            New-Item -ItemType Directory -Force -Path $RemotePath
        }
    } -ComputerName $RemoteServer -ArgumentList $RemotePath
}

function LocalToRemote($LocalPath, $RemoteServer, $RemotePath) {
    Write-Host "Make folder on Remote Server"
    MakeRemoteFolder -RemoteServer $RemoteServer -RemotePath $RemotePath

    Write-Host "Send To Remote Server"
    $TargetSession = New-PSSession -ComputerName $RemoteServer
    Copy-Item -Path $LocalPath -Destination $RemotePath -ToSession $TargetSession -Verbose -Recurse
}

function RemoteToLocal($LocalPath, $RemoteServer, $RemotePath) {
    Write-Host "Make folder on local system"
    If (!(test-path $LocalPath)) {
        New-Item -ItemType Directory -Force -Path $LocalPath
    }

    Write-Host "Receive From Remote Server"
    $TargetSession = New-PSSession -ComputerName $RemoteServer
    Copy-Item -Path $RemotePath -Destination $LocalPath -FromSession $TargetSession -Verbose -Recurse
}

function RemoteToRemote($LocalDestinationPath, $LocalSourcePath, $RemoteServer1, $RemotePath1, $RemoteServer2, $RemotePath2) {
    # Make sure that you have the space needed on the local system, not recomended for big files or folders.

    # Receive From Remote Server 1
    Write-Host "Make folder on local system"
    If (!(test-path $LocalDestinationPath)) {
        New-Item -ItemType Directory -Force -Path $LocalPath
    }

    Write-Host "Receive From Remote Server 1"
    $TargetSession = New-PSSession -ComputerName $RemoteServer1
    Copy-Item -Path $RemotePath1 -Destination $LocalDestinationPath -FromSession $TargetSession -Verbose -Recurse

    # Send To Remote Server
    Write-Host "Make folder on Remote Server 2"
    MakeRemoteFolder -RemoteServer $RemoteServer2 -RemotePath $RemotePath2

    Write-Host "Send To Remote Server 2"
    $TargetSession = New-PSSession -ComputerName $RemoteServer2
    Write-Host "LocalSourcePath $($LocalSourcePath)"
    Copy-Item -Path $LocalSourcePath -Destination $RemotePath2 -ToSession $TargetSession -Verbose -Recurse
}

# RemoteToRemote
Write-Host "RemoteToRemote"
$FolderOrFileToSend = "test" # Eg. "Hallo World.txt" for a file

$LocalDestinationPath = "C:\Test"
$LocalSourcePath = "C:\Test\$($FolderOrFileToSend)"
$RemotePath1 = "C:\Test\$($FolderOrFileToSend)"
$RemoteServer1 = "RemoteServer1"
$RemotePath2 = "C:\Test"
$RemoteServer2 = "RemoteServer2"

RemoteToRemote `
    -LocalDestinationPath $LocalDestinationPath `
    -LocalSourcePath $LocalSourcePath `
    -RemoteServer1 $RemoteServer1 `
    -RemotePath1 $RemotePath1 `
    -RemoteServer2 $RemoteServer2 `
    -RemotePath2 $RemotePath2