param
(
    $region = "us-east-1",
    $ami = "ami-d85e75b0"
)

function Get-IPAddress
{
    $(Invoke-WebRequest -uri "http://ipecho.net/plain").Content;
}

function Get-Password ($length = 20)
{
    $digits = 48..57
    $letters = 65..90 + 97..122

    $password = get-random -count $length `
        -input ($digits + $letters) |
            % -begin { $aa = $null } `
            -process {$aa += [char]$_} `
            -end {$aa}

    return $password
}

function Get-SetupScript
{
    param ($user, $pass, $psk)
    
    $voodooVpnScript = (cat $PSScriptRoot\voodoo_vpn.sh | % {
        $_ -replace "^IPSEC_PSK.*", "IPSEC_PSK=$psk"  `
           -replace "^VPN_USER.*", "VPN_USER=$user" `
           -replace "^VPN_PASSWORD.*", "VPN_PASSWORD=$pass"
    }) -join "`n";

    $shutdownPath = "/usr/bin/shutdown_server.py";
    $shutdownScript = (cat $PSScriptRoot\shutdown_server.py) -join "`n";

    return @("#!/bin/sh",
        "apt-get update",
        $voodooVpnScript,
        "cat << EOF > $shutdownPath",
        $shutdownScript,
        "EOF"
        "chmod +x $shutdownPath",
        "$shutdownPath&") -join "`n";
}

function Add-EC2IngressRule
{
    param ($sourceCidr, $protocol, $port, $groupId);
    $cidrBlocks = New-Object 'collections.generic.list[string]'
    $cidrBlocks.add($sourceCidr)
    $ipPermissions = New-Object Amazon.EC2.Model.IpPermission 
    $ipPermissions.IpProtocol = $protocol; 
    $ipPermissions.FromPort = $port;
    $ipPermissions.ToPort = $port;
    $ipPermissions.IpRanges = $cidrBlocks
    Grant-EC2SecurityGroupIngress -GroupId $groupId -IpPermissions $ipPermissions
}

function ConfigureGroupAndGetID
{
    $name = "VPN";

    try
    {
        $group = Get-EC2SecurityGroup -GroupName $name;
        Write-Host "Updating security group $($group.GroupId)";
    }
    catch
    {
        Write-Host "Adding new security group $($group.GroupId)";
        $id = New-EC2SecurityGroup -GroupName $name -Description "Created by TVPN";
        $group = Get-EC2SecurityGroup -GroupName $name;
    }

    foreach ($permission in $group.IpPermissions)
    {
        Revoke-EC2SecurityGroupIngress -GroupId $group.GroupId -IpPermission $permission;
    }

    $ip = (Get-IPAddress) + "/32";

    # SSH
    Add-EC2IngressRule -groupId $group.GroupId -sourceCidr $ip -port 22 -protocol "tcp";
    
    # Scripts to 
    Add-EC2IngressRule -groupId $group.GroupId -sourceCidr $ip -port 8080 -protocol "tcp";

    # VPN Ports
    Add-EC2IngressRule -groupId $group.GroupId -sourceCidr $ip -port 500 -protocol "tcp";
    Add-EC2IngressRule -groupId $group.GroupId -sourceCidr $ip -port 500 -protocol "udp";
    Add-EC2IngressRule -groupId $group.GroupId -sourceCidr $ip -port 4500 -protocol "udp";

    return $group.GroupId;
}

function CreateKeypairAndGetName
{
    $name = "VPN";
    
    try
    {
        $keypair = Get-EC2KeyPair $name;
        Write-Host "Using existing keypair with fingerprint $($keypair.KeyFingerprint).";
    }
    catch
    {
        $filename = "$PSScriptRoot\vpn-ssh.pem";
        $keypair = New-EC2KeyPair $name;
        $keypair.KeyMaterial | Out-File -FilePath $filename -Encoding ascii;

        Write-Host "A new keypair has been created and stored $filename";
    }

    return $name;
}

function LaunchVPNInstanceAndGetID
{
    param ($script)
    $securityGroupId = ConfigureGroupAndGetID;
    $keypair = CreateKeypairAndGetName;

    Write-Host "Starting new EC2 instance in $region using $ami";    
    $newInstance = New-EC2Instance -ImageId $ami `
        -UserData $script `
        -EncodeUserData `
        -SecurityGroupId $securityGroupId `
        -InstanceType "m1.small" `
        -InstanceInitiatedShutdownBehavior "terminate" `
        -KeyName $keypair;

    $reservation = New-Object 'collections.generic.list[string]';
    $reservation.add($newInstance.ReservationId);
    $filter_reservation = New-Object Amazon.EC2.Model.Filter -Property @{Name = "reservation-id"; Values = $reservation};
    $instance = (Get-EC2Instance -Filter $filter_reservation).Instances[0];

    $tag = New-Object Amazon.EC2.Model.Tag;
    $tag.Key = "Name";
    $tag.Value = "TVPN";
    New-EC2Tag -Resource $instance.InstanceId -Tag $tag;

    return $instance.InstanceId;
}

function WaitForInstance
{
    param ($id)

    do 
    {
        Start-Sleep -Milliseconds 500;
        $instance = (Get-EC2Instance -Instance $id).Instances[0];
    }
    while ($instance.State.Name -ne "running")

    return $instance;
}

function WaitForServer
{
    param ($ip)
    
    while ($true)
    {
        Start-Sleep -Milliseconds 500;

        try
        {
            [void](Invoke-WebRequest -Uri "http://$($ip):8080" -Method Get -TimeoutSec 5);
            return;
        }
        catch
        {
        }
    }   
}

function Configure-VPN
{
    param ($ip, $psk)

    $connection = Get-VpnConnection "TVPN" `
        -ErrorAction SilentlyContinue;

    if ($connection)
    {
        Remove-VpnConnection "TVPN" -Force;
    }

    Add-VpnConnection -Name "TVPN" `
        -ServerAddress $ip `
        -TunnelType "L2TP" `
        -L2tpPsk $psk `
        -AuthenticationMethod "CHAP" `
        -WarningAction SilentlyContinue `
        -Force `
        -RememberCredential;
}


$settings = ([xml](cat "$PSScriptRoot\settings.xml")).config;
Set-DefaultAWSRegion $settings.region;
Set-AWSCredentials -AccessKey $settings.accessKey -SecretKey $settings.secretKey;

$user = Get-Password;
$pass = Get-Password;
$psk = Get-Password;
$script = Get-SetupScript -user $user -pass $pass -psk $psk;

$instanceId = LaunchVPNInstanceAndGetID -script $script;

Write-Host "Instance launched with ID $($instanceId)";
Write-Host "Waiting for instance to launch...";

$instance = WaitForInstance -id $instanceId;
Write-Host "Instance has launched with IP $($instance.PublicIpAddress)";

Write-Host "Configuring VPN connection";
Configure-VPN -ip $instance.PublicIpAddress -psk $psk;

Write-Host "Waiting for instance networking to become available...";
WaitForServer -ip $instance.PublicIpAddress;

Write-Host "Connecting to VPN...";
&rasdial "TVPN" $user $pass

Write-Host ""
Write-Host "Connected. Close this window when you're done with the"
Write-Host "connection and the instance will automatically terminate."

while ($true)
{
    $pingUrl = "http://$($instance.PublicIpAddress):8080/ping";
    [void](Invoke-WebRequest $pingUrl -Method Post  -TimeoutSec 5);
    Start-Sleep -Seconds 30;
}
