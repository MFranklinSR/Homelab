configuration OTHERDC
{
   param
    (
        [String]$TimeZone,
        [String]$DomainName,
        [String]$DNSServerIP,
        [String]$NetBiosDomain,
        [System.Management.Automation.PSCredential]$Admincreds,
        [Int]$RetryCount=20,
        [Int]$RetryIntervalSec=30
    )

    Import-DscResource -Module xStorage
    Import-DscResource -Module xNetworking
    Import-DscResource -Module xPSDesiredStateConfiguration
    Import-DscResource -Module ComputerManagementDsc
    Import-DscResource -Module ActiveDirectoryDsc
    Import-DscResource -Module xPendingReboot    

    [System.Management.Automation.PSCredential ]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${NetBiosDomain}\$($Admincreds.UserName)", $Admincreds.Password)

    $Interface=Get-NetAdapter|Where Name -Like "Ethernet*"|Select-Object -First 1
    $InterfaceAlias=$($Interface.Name)

    Node localhost
    {
        LocalConfigurationManager
        {
            RebootNodeIfNeeded = $true
        }

        xWaitforDisk Disk2
        {
                DiskId = 2
                RetryIntervalSec =$RetryIntervalSec
                RetryCount = $RetryCount
        }

        xDisk ADDataDisk
        {
            DiskId = 2
            DriveLetter = "N"
            DependsOn = "[xWaitForDisk]Disk2"
        }

        WindowsFeature ADDSInstall
        {
            Ensure = "Present"
            Name = "AD-Domain-Services"
        }

        WindowsFeature ADDSTools
        {
            Ensure = "Present"
            Name = "RSAT-ADDS-Tools"
            DependsOn = "[WindowsFeature]ADDSInstall"
        }

        WindowsFeature ADAdminCenter
        {
            Ensure = "Present"
            Name = "RSAT-AD-AdminCenter"
            DependsOn = "[WindowsFeature]ADDSTools"
        }

        xDnsServerAddress DnsServerAddress
        {
            Address        = $DNSServerIP
            InterfaceAlias = $InterfaceAlias
            AddressFamily  = 'IPv4'
            DependsOn="[WindowsFeature]ADDSInstall"
        }

        WaitForADDomain DscForestWait
        {
            DomainName = $DomainName
            Credential= $DomainCreds
            RestartCount = $RetryCount
            WaitTimeout = $RetryIntervalSec
            DependsOn = '[xDNSServerAddress]DnsServerAddress'
        }

        ADDomainController BDC
        {
            DomainName = $DomainName
            Credential = $DomainCreds
            SafemodeAdministratorPassword = $DomainCreds
            DatabasePath = "N:\NTDS"
            LogPath = "N:\NTDS"
            SysvolPath = "N:\SYSVOL"
            DependsOn = "[WaitForADDomain]DscForestWait"
        }

        TimeZone SetTimeZone
        {
            IsSingleInstance = 'Yes'
            TimeZone         = $TimeZone
        }

        Script UpdateDNSSettings
        {
            SetScript =
            {
                # Reset DNS
                Set-DnsClientServerAddress -InterfaceAlias "$using:InterfaceAlias" -ResetServerAddresses
            }
            GetScript =  { @{} }
            TestScript = { $false}
            DependsOn = '[xDNSServerAddress]DnsServerAddress'
        }

        xPendingReboot RebootAfterPromotion {
            Name = "RebootAfterDCPromotion"
            DependsOn = "[Script]UpdateDNSSettings"
        }               
    }
}