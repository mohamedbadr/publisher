function Backup-RemoteFolder {
    param (
        [string]$RemoteServer,
        [string]$RemotePath,
        [string]$LocalPath
    )

    Write-Host "Make folder on local system"
    If (!(test-path $LocalPath)) {
        New-Item -ItemType Directory -Force -Path $LocalPath
    }

    Write-Host "Receive From Remote Server"
    $TargetSession = New-PSSession -ComputerName $RemoteServer
    Copy-Item -Path $RemotePath -Destination $LocalPath -FromSession $TargetSession -Verbose -Recurse
}