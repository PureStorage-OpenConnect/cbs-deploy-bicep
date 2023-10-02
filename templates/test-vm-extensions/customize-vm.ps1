param ([Parameter(Mandatory)]$PureManagementIP,$PureManagementUser, $PureManagementPassword, $VmUser, $SSHPrivateKeyBase64 = '')
#Variables
$arrayendpoint = $PureManagementIP
$pureuser = $PureManagementUser
$purepass = ConvertTo-SecureString $PureManagementPassword -AsPlainText -Force
$purecred = New-Object System.Management.Automation.PSCredential -ArgumentList ($pureuser, $purepass)

# install Microsoft Edge
mkdir -Path $env:temp\edgeinstall -erroraction SilentlyContinue | Out-Null
$Download = join-path $env:temp\edgeinstall MicrosoftEdgeEnterpriseX64.msi

Invoke-WebRequest 'https://msedge.sf.dl.delivery.mp.microsoft.com/filestreamingservice/files/a2662b5b-97d0-4312-8946-598355851b3b/MicrosoftEdgeEnterpriseX64.msi'  -OutFile $Download

Start-Process "$Download" -ArgumentList "/quiet /passive"

reg add "HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Edge" /v HideFirstRunExperience /t REG_DWORD /d 1 /reg:64 /f

reg add "HKEY_CURRENT_USER\Software\Policies\Microsoft\Edge" /v HideFirstRunExperience /t REG_DWORD /d 1 /reg:64 /f



# ignore self-signed cert
add-type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllCertsPolicy : ICertificatePolicy {
    public bool CheckValidationResult(
        ServicePoint srvPoint, X509Certificate certificate,
        WebRequest request, int certificateProblem) {
        return true;
    }
}
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Ssl3, [Net.SecurityProtocolType]::Tls, [Net.SecurityProtocolType]::Tls11, [Net.SecurityProtocolType]::Tls12



# create a desktop icon to disk management tool  
$WshShell = New-Object -comObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("C:\Users\Public\Desktop\Disk Management.lnk")
$Shortcut.TargetPath = "C:\Windows\system32\diskmgmt.msc"
$shortcut.IconLocation =  "C:\Windows\system32\mmc.exe"
$Shortcut.Save()



# download Pure favicon 
mkdir -Path $env:temp\purecustomization -erroraction SilentlyContinue | Out-Null
$DownloadFavicon = join-path $env:temp\purecustomization favicon.ico
Invoke-WebRequest "https://support.purestorage.com/@api/deki/files/47337/pcbs.ico?origin=mt-web" -OutFile $DownloadFavicon 

# create a desktop icon to mgmt. interface

$WshShell = New-Object -comObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("C:\Users\Public\Desktop\Open CBS Console.lnk")
$Shortcut.TargetPath = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
$shortcut.IconLocation =  $DownloadFavicon
$Shortcut.Arguments = "https://$arrayendpoint"
$Shortcut.Save()




# copy the ssh private key into desktop
if (-not ([string]::IsNullOrEmpty($SSHPrivateKeyBase64)))
{
    $sshKeyFilename = "C:\ssh.key"
    Write-Host $SSHPrivateKeyBase64

    [System.Convert]::FromBase64String($SSHPrivateKeyBase64) | Set-Content $sshKeyFilename -Encoding Byte
    
    # remove other permissions
    Icacls $sshKeyFilename /Inheritance:r
    Icacls $sshKeyFilename /Grant:r ${vmUser}:"(R)"


    # create a desktop icon to ssh the array

    $WshShell = New-Object -comObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut("C:\Users\Public\Desktop\SSH Access to CBS.lnk")
    $Shortcut.TargetPath = "C:\Windows\System32\OpenSSH\ssh.exe"
    $shortcut.IconLocation =  $DownloadFavicon
    $Shortcut.Arguments = "$pureuser@$arrayendpoint -i $sshKeyFilename"
    $Shortcut.Save()

}