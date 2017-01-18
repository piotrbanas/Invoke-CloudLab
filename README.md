# Invoke-CloudLab
The purpose of this project is the comparison of major cloud providers in regards to administrative ease of use.

Usage:
Invoke-CloudLab -cloud AWS
Spawns a simple enviroment with two load-balanced LAMP servers and tests them.
Stores lab information (IPs, load balancer address, instance Ids) in xml file. 
Can be retrieved with Import-clixml .\AWS\awslab.xml
Remove-AWSLab - flushes the environment.

Invoke-CloudLab -cloud Azure
On first use will ask for Azure authentication. It will then register an Azure AD App and securely store it's credentials in xml file for further use.
Assuming single active subscription.
