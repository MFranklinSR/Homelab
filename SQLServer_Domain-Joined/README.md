# SQL Server Domain-Joined Lab

Click the button below to deploy

[![Deploy To Azure](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.svg?sanitize=true)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Felliottfieldsjr%2FKillerHomeLab%2FDevelopment%2FSQLServer_Domain-Joined%2Fazuredeploy.json)
[![Deploy To Azure US Gov](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazuregov.svg?sanitize=true)](https://portal.azure.us/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Felliottfieldsjr%2FKillerHomeLab%2FDevelopment%2FSQLServer_Domain-Joined%2Fazuredeploy.json)

This Templates IS MEANT TO BE USED AS AN ADD-ON to the following labs due to its Domain Membership:
**** THE PARAMETERS SPECIFIED FOR THIS ADD-ON LAB MUST MATCH THE PARAMETERS OF THE BASE LAB THAT IT WILL BE ADDED TO ****

- 1-Forest_1-DomainController_1-Workstation
- 1-Forest_2-DomainControllers_2-ADSites_2-Workstations
- 1-Forest_Parent-Child-Domain_1-Workstation
- Exchange2010-1-Forest_2-DomainControllers_2-ADSites_2-Workstations
- Exchange2010-with-External-Access-1-Forest_2-DomainControllers_2-ADSites_2-Workstations
- Exchange2013-1-Forest_2-DomainControllers_2-ADSites_2-Workstations
- Exchange2013-with-External-Access-1-Forest_2-DomainControllers_2-ADSites_2-Workstations
- Exchange2016-1-Forest_2-DomainControllers_2-ADSites_2-Workstations
- Exchange2016-with-External-Access-1-Forest_2-DomainControllers_2-ADSites_2-Workstations
- Exchange2019-1-Forest_2-DomainControllers_2-ADSites_2-Workstations
- Exchange2019-with-External-Access-1-Forest_2-DomainControllers_2-ADSites_2-Workstations
- PKI_2-Tier_CA_With_OCSP_1-Workstation
- PKI_Enterprise_CA_With_OCSP_1-Workstation
- SQL2019-AlwaysOn-Multi-NIC
- SQL2019-AlwaysOn-Single-NIC


The Template deploys the folowing:

- 1 - Domain Joined SQL Server

The deployment leverages Desired State Configuration scripts to further customize the following:

SQL Deployment
- Installs SQL Server 2017/2019 based on selection
- Installs SQL Management Studio

Parameters that support changes
- TimeZone.  Select an appropriate Time Zone.
- AutoShutdownEnabled.  Yes = AutoShutdown Enabled, No = AutoShutdown Disabled.
- AutoShutdownTime.  24-Hour Clock Time for Auto-Shutdown (Example: 1900 = 7PM)
- AutoShutdownEmail.  Auto-Shutdown notification Email (Example:  user@domain.com)
- Admin Username.  Enter a valid Admin Username
- Admin Password.  Enter a valid Admin Password
- WindowsServerLicenseType.  Choose Windows Seer License Type (Example:  Windows_Server or None)
- SQLSASURL.  Enter a valid URL that points to the SQL 2019 or 2017 .ISO
- SQLNode.  SQL Server Node Number (Example:  01)
- SQLLastOctet.  Provide a value for the Last IP Octet of your SQL Server.
- Naming Convention. Enter a name that will be used as a naming prefix for (Servers, VNets, etc) you are using.
- Sub DNS Domain.  OPTIONALLY, enter a valid DNS Sub Domain. (Example:  sub1. or sub1.sub2.    This entry must end with a DOT )
- Sub DNS BaseDN.  OPTIONALLY, enter a valid DNS Sub Base DN. (Example:  DC=sub1, or DC=sub1,DC=sub2,    This entry must end with a COMMA )
- Net Bios Domain.  Enter a valid Net Bios Domain Name (Example:  sub1).
- Internal Domain.  Enter a valid Internal Domain (Exmaple:  killerhomelab)
- InternalTLD.  Select a valid Top-Level Domain using the Pull-Down Menu.
- Vnet1ID.  Enter first 2 octets of your desired Address Space for Virtual Network 1 (Example:  10.1)
- SQLOSVersion.  Select 2022-Datacenter (Windows 2022), 2019-Datacenter (Windows 2019) or 2016-Datacenter (Windows 2016) SQL OS Version
- SQLVMSize.  Enter a Valid VM Size based on which Region the VM is deployed.