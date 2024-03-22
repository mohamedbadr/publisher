### run this on the client first
#Get-Item WSMan:\localhost\Client\TrustedHosts
#Set-Item WSMan:\localhost\Client\TrustedHosts -Value '192.168.13.15' -Concatenate

$remoteComputer = "192.168.13.15"
$remoteApiFolder = "C:\inetpub\wwwroot\wafi-api"
$remoteBackupFolder = "D:\AutoPublishBackup"
$remoteUsername = "twaijri-kw\pay.server"
$remotePassword = ConvertTo-SecureString "Fmt@P@ssw0rd2019" -AsPlainText -Force

$session  = New-PSSession -ComputerName $remoteComputer -Credential (New-Object System.Management.Automation.PSCredential $remoteUsername, $remotePassword)

if ($null -eq $session) {
    Write-Host "Error: Failed to create session with remote computer."
    Exit-Code 1
  }

  try {
    # Copy the folder from remote machine to local machine
    $currentDateTime  = Get-Date
    $remoteBackupFolder = $remoteBackupFolder+"\api\"+$currentDateTime.ToString("ddMMyyyyHHmmss")
    Write-Host $remoteBackupFolder
    Copy-Item -Path $remoteApiFolder -Destination "\\$remoteComputer\$remoteBackupFolder" -Recurse -FromSession $session
    Write-Host "Folder copied successfully from remote computer!"
  } catch {
    Write-Host "Error: Failed to copy folder. $_"  # Capture and display the error message
    Exit-Code 1
  } finally {
    # Close the remote PowerShell session
    Remove-PSSession $session
  }
