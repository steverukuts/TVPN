$instanceId = "i-94b9906b";

$settings = ([xml](cat "$PSScriptRoot\settings.xml")).config;
Set-DefaultAWSRegion $settings.region;
Set-AWSCredentials -AccessKey $settings.accessKey -SecretKey $settings.secretKey;

Write-Host "Starting $instanceId";
[void](Start-EC2Instance -InstanceId $instanceId);

do
{
    Write-Host "Waiting for host to start...";
    Start-Sleep -Seconds 2;
    $instance = $(Get-EC2Instance $instanceId).Instances[0];
}
while ($instance.State.Name -ne "running")

$ip = $instance.PublicIpAddress;
Write-Host "Instance has started. IP is $($ip).";

Write-Host "Exit this process to shut down the instance.";

while ($true)
{
    $pingUrl = "http://$($ip):8080/ping";
    [void](Invoke-WebRequest $pingUrl);
    Start-Sleep -Seconds 60;
}
