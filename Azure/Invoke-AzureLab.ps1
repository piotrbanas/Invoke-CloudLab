function Register-AzureApp {

Add-AzureRmAccount | Out-Null

$password = -join ([char[]](65..90+97..122)*100 | Get-Random -Count 19)
Get-AzureRmADApplication -IdentifierUri "http://AzureTestLab" | Remove-AzureRmADApplication -Force
$app = New-AzureRmADApplication –DisplayName "Azure Test Lab" –HomePage "http://AzureTestLab" –IdentifierUris "http://AzureTestLab" –Password $password
New-AzureRmADServicePrincipal –ApplicationId $app.ApplicationId | out-null
Start-Sleep -Seconds 30
New-AzureRmRoleAssignment –RoleDefinitionName Contributor –ServicePrincipalName $($app.ApplicationId) | out-null
$subs = Get-AzureRmSubscription

$azureAppObjectProperties = @{
    Name = 'Azure Test Lab'
    Password = ConvertTo-SecureString $password -AsPlainText -Force | ConvertFrom-SecureString
    ApplicationId = $app.ApplicationId
    TenantId = $subs.TenantId
    }

New-Object -TypeName psobject -Property $azureAppObjectProperties | Export-Clixml -path $home\azureLabApp.xml


} # end function

function Test-IsAdmin {
([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
}

Function Invoke-AzureLab {

#region Azurerm module
Import-module Azurerm
If (! (Get-module Azurerm)) {
    if (!(Test-IsAdmin)){
        throw "Need to install Azure module from PSGallery. Please run this script with admin priviliges or manually install the module."
    }
    else {
        Try { 
              Install-Module Azurerm -Force -ErrorAction Stop
              Import-Module Azurerm
            }
        Catch { Throw $Error }
    }
} # End if
#endregion
#region building credentials
$azureAuthfile = "$HOME\azureLabApp.xml"
if (!(Test-Path $azureAuthfile)) {
    $azureAppObject = Register-AzureApp
}
$azureAppObject = Import-Clixml $home\azureLabApp.xml
$azureuser = $azureAppObject.ApplicationId.ToString()
$azurepasss = $azureAppObject.Password | ConvertTo-SecureString
$azureCred = new-object System.Management.Automation.PSCredential($azureuser, $azurepasss)

Add-AzureRmAccount -Credential $azureCred -TenantId $azureAppObject.TenantId -ServicePrincipal
#endregion




} # end invoke-AzureTestLab