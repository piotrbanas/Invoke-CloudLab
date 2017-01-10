<#
.Synopsis
   Stand, test and destroy simple cluoud lab.
.DESCRIPTION
   Long description
.EXAMPLE
   The purpose of this project is the comparison of major cloud providers in regards to administrative ease of use.
.EXAMPLE
   Invoke-CloudLab.ps1 -cloud AWS
.NOTES
   Assumes clean Window 10 workstation. Requires credential files.
#>
function Invoke-CloudLab
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    Param
    (
        # Cloud Platform selection
        [Parameter(Mandatory=$true, 
                   Position=0)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [ValidateSet("AWS", "Azure", "DO")]
        [Alias("c")] 
        [String]$Cloud,

        # Credential file path
        [parameter(
                   Position=1)]
        [ValidateScript({Test-Path $_})]
        [String]$CredFile = "$PSScriptRoot\$Cloud\$cloud"+'Cred.txt'
    )

# dot-sourcing scripts
. $PSScriptRoot\AWS\Invoke-AWSLab.ps1
. $PSScriptRoot\Azure\Invoke-AzureLab.ps1
. $PSScriptRoot\DO\Invoke-DOLab.ps1

Switch ($cloud) {
    "AWS" {
        Invoke-AWSLab -credfile $Credfile
    }
    "Azure" {
        Invoke-AzureLab -credfile $Credfile
    }
    "DO" {
        Invoke-DOLab -credfile $CredFile
    }
}
}