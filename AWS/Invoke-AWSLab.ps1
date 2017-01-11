
<#
.Synopsis
   Launch EC2 lab
.DESCRIPTION
   Long description
.PARAMETER credfile
   Path to credential file. Should be in .aws\credentials format:
   [ProfileName]
   aws_access_key_id=XXXXXXX
   aws_secret_access_key=XXXXXXXX
.EXAMPLE
   Example of how to use this cmdlet
#>
function Invoke-AWSLab
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
$awscredentials = Get-Content $CredFile
$awsprofile = ($credentials[0].Split('[').Split(']'))[1]
$aws_access_key_id = ($credentials[1].Split('='))[1]
$aws_secret_access_key = ($credentials[2].Split('='))[1]

Set-AWSCredentials -AccessKey $aws_access_key_id -SecretKey $aws_secret_access_key -StoreAs $awsprofile
Initialize-AWSDefaults -ProfileName $awsprofile -Region eu-central-1
#endregion

#region Configure and launch instances
$cidrBlocks = New-Object 'collections.generic.list[string]'
$cidrBlocks.add("0.0.0.0/0")
$httpRule = New-Object Amazon.EC2.Model.IpPermission
$httpRule.IpProtocol = "tcp" 
$httpRule.FromPort = 80
$httpRule.ToPort = 80
$httpRule.IpRanges = $cidrBlocks
$httpgroupid = New-EC2SecurityGroup -GroupName AWSLabSecurityGroup -Description 'Ec2-Classic Security Group for Lab purposes'
Grant-EC2SecurityGroupIngress -GroupID $httpgroupid -IpPermissions $httpRule

$AWSLabInstances = New-EC2Instance -InstanceType t2.micro -ImageId ami-fe408091 -MinCount 2 -MaxCount 2 -SecurityGroupId $httpgroupid
Start-Sleep -Seconds 60
While ((Get-Ec2InstanceStatus -InstanceId $AWSLabInstances).InstanceState.Name.Value[0] -ne 'running') 
    {
        Start-Sleep -Seconds 30
    }
$IPs = ((Get-EC2Instance -InstanceId $AWSLabInstances).RunningInstance).publicipaddress
Write-output $IPs
#endregion
Clear-AWSCredentials -ProfileName $awsprofile
} # End function