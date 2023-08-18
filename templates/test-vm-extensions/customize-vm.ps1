param ([Parameter(Mandatory)]$PureManagementIP,$PureManagementUser, $PureManagementPassword)
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
$Download = join-path $env:temp\purecustomization favicon.ico
Invoke-WebRequest "https://support.purestorage.com/@api/deki/files/47337/pcbs.ico?origin=mt-web" -OutFile $Download 

# create a desktop icon to mgmt. interface

$WshShell = New-Object -comObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("C:\Users\Public\Desktop\Open CBS Console.lnk")
$Shortcut.TargetPath = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
$shortcut.IconLocation =  $Download
$Shortcut.Arguments = "https://$arrayendpoint"
$Shortcut.Save()