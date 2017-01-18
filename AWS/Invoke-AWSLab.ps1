

function Invoke-AWSLab
<#
.Synopsis
   Launch EC2 lab
.DESCRIPTION
   Launches a simple enviroment with two load-balanced LAMP servers.
.PARAMETER credfile
   Path to credential file. Should be in .aws\credentials format:
   [ProfileName]
   aws_access_key_id=XXXXXXX
   aws_secret_access_key=XXXXXXXX
.EXAMPLE
   Invoke-AWSLab -credfile "$HOME\awssecret.txt
#>
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Position=0)]
        [ValidateScript({Test-Path $_})]
        [String]$CredFile = "$Home\.aws\credentials"
    )

#region Check for AWS module
function Test-IsAdmin {
([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
}
Import-module AWSPowershell
If (! (Get-module AWSPowershell)) {
    if (!(Test-IsAdmin)){
        throw "Need to install AWSPowershell module from PSGallery. Please run this script with admin priviliges or manually install the module."
    }
    else {
        Try { 
              Install-Module AWSPowershell -Force -ErrorAction Stop
              Import-Module AWSPowershell
            }
        Catch { Throw $Error }
    }
} # End if
#endregion
#region build credentials
Write-Verbose "Building credentials from $credfile"
$awscredentials = Get-Content $CredFile
$awsprofile = ($awscredentials[0].Split('[').Split(']'))[1]
$aws_access_key_id = ($awscredentials[1].Split('='))[1]
$aws_secret_access_key = ($awscredentials[2].Split('='))[1]

Set-AWSCredentials -AccessKey $aws_access_key_id -SecretKey $aws_secret_access_key -StoreAs $awsprofile
Initialize-AWSDefaults -ProfileName $awsprofile -Region eu-central-1
#endregion
#region Configure security group
If (!(Get-EC2SecurityGroup -GroupName AWSLabSecurityGroup)) {
    Write-Verbose "Security group not found. Adding."
    $cidrBlocks = New-Object 'collections.generic.list[string]'
    $cidrBlocks.add("0.0.0.0/0")

    $httpRule = New-Object Amazon.EC2.Model.IpPermission
    $httpRule.IpProtocol = "tcp" 
    $httpRule.FromPort = 80
    $httpRule.ToPort = 80
    $httpRule.IpRanges = $cidrBlocks

    $HTTPSRule = New-Object Amazon.EC2.Model.IpPermission 
    $HTTPSRule.IpProtocol='tcp' 
    $HTTPSRule.FromPort = 443 
    $HTTPSRule.ToPort = 443 
    $HTTPSRule.IpRanges = $cidrBlocks

    $httpgroupid = New-EC2SecurityGroup -GroupName AWSLabSecurityGroup -Description 'Ec2-Classic Security Group - allow HTTP/S'
    Grant-EC2SecurityGroupIngress -GroupID $httpgroupid -IpPermissions $httpRule, $HTTPSRule
} 
Else {
        $httpgroupid = (Get-EC2SecurityGroup -GroupName AWSLabSecurityGroup).GroupID
        Write-Verbose "Secuirty group exists $httpgroupid"
}
#endregion
#region Spawn instances
$UserData = @'
#!/bin/bash
yum update -y
yum install -y httpd24 php56 mysql55-server php56-mysqlnd
service httpd start
chkconfig httpd on
groupadd www
usermod -a -G www ec2-user
chown -R root:www /var/www
chmod 2775 /var/www
find /var/www -type d -exec chmod 2775 {} +
find /var/www -type f -exec chmod 0664 {} +
echo "<?php phpinfo(); ?>" > /var/www/html/phpinfo.php
'@
$UserDataB64 = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($UserData))
Write-Verbose "Spawning instances..."
$AWSLabReserve = New-EC2Instance -InstanceType t2.micro -ImageId ami-211ada4e -MinCount 2 -MaxCount 2 -SecurityGroupId $httpgroupid -UserData $UserDataB64 -AvailabilityZone eu-central-1b
$SingleInstanceState = $AWSLabReserve.RunningInstance[0]
Start-Sleep -Seconds 60
While ((Get-Ec2InstanceStatus -InstanceId $SingleInstanceState.InstanceId).InstanceState.Name -ne 'running') 
    {
        Write-Verobse "Waiting for Instance to become available..."
        Start-Sleep -Seconds 30
        $SingleInstanceState = (Get-EC2Instance -Instance $SingleInstanceState.InstanceID).RunningInstance[0]
    }
$IPs = ((Get-EC2Instance -InstanceId $AWSLabReserve).RunningInstance).publicipaddress
#endregion
#region load balancer
$HTTPListener = New-Object -TypeName ‘Amazon.ElasticLoadBalancing.Model.Listener’
$HTTPListener.Protocol = ‘http’
$HTTPListener.InstancePort = 80
$HTTPListener.LoadBalancerPort = 80
$LaunchedInstances = Get-EC2InstanceStatus -InstanceId $AWSLabReserve
Write-Verbose "Adding Load Balancer"
New-ELBLoadBalancer -LoadBalancerName 'LabLoadBalancer' -Listener $HTTPListener -AvailabilityZone eu-central-1b -OutVariable ELB
Write-Verbose "Registering instances with load balancer"
Register-ELBInstanceWithLoadBalancer -LoadBalancerName 'LabLoadBalancer' -Instances $LaunchedInstances.InstanceID


#endregion
$Props = @{
    Ids = $LaunchedInstances.InstanceId
    IPs = $Ips | Where-Object {$_ -ne $null}
    LBAddress = $ELB
}
$AWSLab = New-Object -TypeName PSObject -Property $props
Write-Verbose $AWSLab
$AWSLab | Export-Clixml (Join-path $PSScriptRoot awslab.xml)
} # End function

Function Remove-AWSLab {
    $AWSLab = Import-Clixml '.\AWS\awslab.xml'
    Remove-ELBLoadBalancer -LoadBalancerName 'LabLoadBalancer' -force
    Get-EC2Instance -InstanceId $AWSLab.Ids | Remove-EC2Instance -force
    Remove-Item .\AWS\awslab.xml
}