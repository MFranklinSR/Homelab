# Exchange 2019 Lab with External Access Single-Site

Click a button below to deploy to the cloud of your choice

[![Deploy To Azure](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.svg?sanitize=true)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FMFranklinSR%2FHomeLab%2Fmaster%2FExchange2019-with-External-Access-1-Forest_1-DomainController_1-ADSite_1-Workstation%2Fazuredeploy.json)
[![Deploy To Azure US Gov](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazuregov.svg?sanitize=true)](https://portal.azure.us/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Felliottfieldsjr%2FKillerHomeLab%2Fmaster%2FExchange2019-with-External-Access-1-Forest_1-DomainController_1-ADSite_1-Workstation%2Fazuredeploy.json)

!!!!NOTE:  PLEASE MAKE SURE TO APPLY CRITICAL SECURITY UPDATE KB5000871 TO BOTH EXCHANGE SERVERS AFTER THE DEPLOYMENT IS COMPLETE.

This Templates deploys a Single Forest/Domain:

- 1 - Active Directory Forest/Domain
- 1 - Active Directory Site
- 1 - Domain Controller
- 1 - Offline Root Certificate Authority Server
- 1 - Issuing Certificate Authority Server
- 1 - Online Certificate Status Protocol Server
- 1 - Exchange 2019 Organization
- 1 - Exchange 2019 Server
- 1 - File Share Witness Server (Exchange Witness Server)
- 1 - Database Availability Group
- 1 - Domain Joined Windows 10 Workstation
- 1 - Azure DNS Zone (Created based on NetBiosDomain and TLD Parameters)
- 1 - Network Security Group
- 1 - Bastion Host (VNet1)

The deployment also makes the following customizations:
- Adds Public IP Address to OCSP and Exchange Servers.
- Creates Azure DNS Zone Records based on the correesponding Servers Public IP
- -- OCSP (OCSP VM Public IP)
- -- OWA2019 (Exchange VM1 Public IP)
- -- OWA2019 (Exchange VM2 Public IP)
- -- AUTODISCOVER (Exchange VM1 Public IP)
- -- AUTODISCOVER (Exchange VM2 Public IP)
- -- OUTLOOK2019 (Exchange VM1 Public IP)
- -- OUTLOOK2019 (Exchange VM2 Public IP)
- -- EAS2019 (Exchange VM1 Public IP)
- -- EAS2019 (Exchange VM2 Public IP)
- -- SMTP (Exchange VM1 Public IP)
- -- SMTP (Exchange VM2 Public IP)

The deployment leverages Desired State Configuration scripts to further customize the following:

AD OU Structure:
- [domain.com]
- -- Accounts
- --- End User
- ---- Office 365
- ---- Non-Office 365
- --- Admin
- --- Service
- -- Groups
- --- End User
- --- Admin
- -- Servers
- --- Servers2012R2
- --- Servers2016
- --- Servers2019
- -- MaintenanceServers
- -- MaintenanceWorkstations
- -- Workstations
- --- Windows10
- --- Windows7

AD DNS Zone Record Creation:
- CRL (For CRL Download)
- OCSP (For OCSP Server)
- OWA2019 (For Exchange Server1)
- OWA2019 (For Exchange Server2)
- AUTODISCOVER2019 (For Exchange Server1)
- AUTODISCOVER2019 (For Exchange Server2)
- OUTLOOK2019 (For Exchange Server1)
- OUTLOOK2019 (For Exchange Server2)
- EAS2019 (For Exchange Server1)
- EAS2019 (For Exchange Server2)
- SMTP (For Exchange Server1)
- SMTP (For Exchange Server2)

PKI
- Offline Root CA Configuaration
- Issuing CA Configuration
- OCSP Configuaration

Exchange
- File Share Witness Creation
- Exchange 2019 OS Prerequisites
- Exchange 2019 Installation
- Request/Receive Exchange 2019 SAN Certificate from Issuing CA
- Exchange 2019 Certificate Enablement
- Exchange Virtual Directory Internal/External Configuration
- Exchange Virtual Directory Authentication Configuration
- DAG Creation and Adding both Exchange Servers

Parameters that support changes
- TimeZone.  Select an appropriate Time Zone.
- Exchange Org Name. Enter a name that will be used for your Exchange Organization Name.
- Exchange2019ISOUrl.  You must enter a URL or created SAS URL that points to an Exchange 2019 ISO for this installation to be successful.
- Admin Username.  Enter a valid Admin Username
- Admin Password.  Enter a valid Admin Password
- WindowsServerLicenseType.  Choose Windows Server License Type (Example:  Windows_Server or None)
- WindowsClientLicenseType.  Choose Windows Client License Type (Example:  Windows_Client or None)
- To Email.  Please provide a working email address that the Trusted Certificate Authority Chain Can be sent to.  These certificates will allow access to Exchange Services like OWA, EAS and Outlook without Certificate Security warnings. (Depending on What Public IP you get initially.  Exchange mailflow may be blocked if it's blacklisted)
- Naming Convention. Enter a name that will be used as a naming prefix for (Servers, VNets, etc) you are using.
- Sub DNS Domain.  OPTIONALLY, enter a valid DNS Sub Domain. (Example:  sub1. or sub1.sub2.    This entry must end with a DOT )
- Sub DNS BaseDN.  OPTIONALLY, enter a valid DNS Sub Base DN. (Example:  DC=sub1, or DC=sub1,DC=sub2,    This entry must end with a COMMA )
- Net Bios Domain.  Enter a valid Net Bios Domain Name (Example:  killerhomelab).
- Internal Domain.  Enter a valid Internal Domain (Exmaple:  killerhomelab)
- InternalTLD.  Select a valid Top-Level Domain for your Internal Domain using the Pull-Down Menu.
- External Domain.  Enter a valid External Domain (Exmaple:  killerhomelab)
- ExternalTLD.  Select a valid Top-Level Domain for your External Domain using the Pull-Down Menu.
- Vnet1ID.  Enter first 2 octets of your desired Address Space for Virtual Network 1 (Example:  19.1)
- Reverse Lookup1.  Enter first 2 octets of your desired Address Space in Reverse (Example:  1.19)
- Root CA Name.  Enter a Name for your Root Certificate Authority
- Issuing CA Name.  Enter a Name for your Issuing Certificate Authority
- RootCAHashAlgorithm.  Hash Algorithm for Offline Root CA
- RootCAKeyLength.  Key Length for Offline Root CA
- IssuingCAHashAlgorithm.  Hash Algorithm for Issuing CA
- IssuingCAKeyLength.  Key Length for Issuing CA
- DC1OSVersion.  Select 2016-Datacenter (Windows 2016) or 2019-Datacenter (Windows 2019) Domain Controller 1 OS Version
- RCAOSVersion.  Select 2016-Datacenter (Windows 2016) or 2019-Datacenter (Windows 2019) Root CA OS Version
- ICAOSVersion.  Select 2016-Datacenter (Windows 2016) or 2019-Datacenter (Windows 2019) Issuing CA OS Version
- OCSPOSVersion.  Select 2016-Datacenter (Windows 2016) or 2019-Datacenter (Windows 2019) OCSP OS Version
- FSOSVersion.  Select 2016-Datacenter (Windows 2016) or 2019-Datacenter (Windows 2019) File ShareWiteness OS Version
- EXOSVersion.  Exchange Servers OS Version is not configurable and set to 2019-Datacenter (Windows 2019).
- WK1OSVersion.  Workstation1 OS Version is not configurable and set to 19h1-pro (Windows 10).
- DC1VMSize.  Enter a Valid VM Size based on which Region the VM is deployed.
- RCAVMSize.  Enter a Valid VM Size based on which Region the VM is deployed.
- ICAVMSize.  Enter a Valid VM Size based on which Region the VM is deployed.
- OCSPVMSize.  Enter a Valid VM Size based on which Region the VM is deployed.
- FS1VMSize.  Enter a Valid VM Size based on which Region the VM is deployed.
- EX1VMSize.  Enter a Valid VM Size based on which Region the VM is deployed.
- WK1VMSize.  Enter a Valid VM Size based on which Region the VM is deployed.
