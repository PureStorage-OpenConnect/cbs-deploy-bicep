param ([Parameter(Mandatory)]$PureManagementIP,$PureManagementUser,$PureManagementPassword)
#Variables
$arrayendpoint = $PureManagementIP
$pureuser = $PureManagementUser
$purepass = ConvertTo-SecureString $PureManagementPassword -AsPlainText -Force
$purecred = New-Object System.Management.Automation.PSCredential -ArgumentList ($pureuser, $purepass)
$computername = [System.Net.Dns]::GetHostName()


#Install Pure Powershell Module
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
Install-Module PureStoragePowershellSDK2 -Confirm:$false -Force

#Enable ISCSI
Set-Service -Name msiscsi -StartupType Automatic
Start-Service -Name msiscsi

#Confgure Static Initiator Name
$iqn = (Get-InitiatorPort).NodeAddress

# Connect to Cloud Block Store
$array = Connect-Pfa2Array -Endpoint $arrayendpoint -Credential $purecred -IgnoreCertificateError

#Create Host and Volume
$purehost = New-Pfa2Host -Array $array -Name $computername -Iqns $iqn
$purevolume = New-Pfa2Volume -Array $array -Name $computername'-SQLData' -Provisioned 1PB
$purevolume2 = New-Pfa2Volume -Array $array -Name $computername'-SQLLogs' -Provisioned 20GB
$purevolume3 = New-Pfa2Volume -Array $array -Name $computername'-SQLTemp' -Provisioned 10GB

New-Pfa2Connection -Array $array -HostNames $purehost.name -VolumeNames $purevolume.name,$purevolume2.name,$purevolume3.name

#Get iSCSI Information
$iscsiInterface = Get-Pfa2NetworkInterface|Where-Object {$_.Services -eq 'iscsi'}
$ct0iscsi = $iscsiInterface[0].Eth.Address
$ct1iscsi = $iscsiInterface[1].Eth.Address

#Configure ISCSI to CBS
if ((Get-IscsiTargetPortal).TargetPortalAddress -notcontains $ct0iscsi){
    New-IscsiTargetPortal -TargetPortalAddress $ct0iscsi
    Get-IscsiTarget | Connect-IscsiTarget -InitiatorPortalAddress (Get-NetIPAddress |Where-Object {$_.InterfaceAlias -like "Ethernet*" -and $_.AddressFamily -like "IPv4"}).IPAddress -IsPersistent $true -TargetPortalAddress $ct0iscsi
}
if ((Get-IscsiTargetPortal).TargetPortalAddress -notcontains $ct1iscsi){
    New-IscsiTargetPortal -TargetPortalAddress $ct1iscsi
    Get-IscsiTarget | Connect-IscsiTarget -InitiatorPortalAddress (Get-NetIPAddress |Where-Object {$_.InterfaceAlias -like "Ethernet*" -and $_.AddressFamily -like "IPv4"}).IPAddress -IsPersistent $true -TargetPortalAddress $ct1iscsi
}

#Initialize and Format Disk
Update-HostStorageCache #Rescan for Disks
Get-Disk|Where-Object {$_.NumberOfPartitions -eq '0'}|Initialize-Disk -PartitionStyle 'GPT' #Initialize Disk in GPT
