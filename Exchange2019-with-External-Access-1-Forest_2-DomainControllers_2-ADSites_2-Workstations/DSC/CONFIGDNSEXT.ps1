configuration CONFIGDNSEXT
{
   param
   (
        [String]$computerName,
        [String]$DC2Name,
        [String]$NetBiosDomain,
        [String]$InternaldomainName,
        [String]$ExternaldomainName,
        [String]$ReverseLookup1,
        [String]$ReverseLookup2,
        [String]$ForwardLookup1,
        [String]$ForwardLookup2,
        [String]$dc1lastoctet,
        [String]$dc2lastoctet,
        [String]$icaIP,
        [String]$ocspIP,
        [String]$ex1IP,
        [String]$ex2IP,
        [Int]$RetryIntervalSec=420,
        [System.Management.Automation.PSCredential]$Admincreds
    )

    Import-DscResource -ModuleName DnsServerDsc
    Import-DscResource -ModuleName ActiveDirectoryDsc

    [System.Management.Automation.PSCredential ]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${NetBiosDomain}\$($Admincreds.UserName)", $Admincreds.Password)

    Node localhost
    {
        WaitForADDomain DscForestWait
        {
            DomainName = $InternaldomainName
            Credential= $DomainCreds
            WaitTimeout = $RetryIntervalSec
        }

        DnsServerADZone ExternalDomain
        {
            Name             = "$ExternaldomainName"
            DynamicUpdate = 'Secure'
            Ensure           = 'Present'
            ReplicationScope = 'Domain'
            DependsOn = '[WaitForADDomain]DscForestWait'
        }

        DnsServerADZone ReverseADZone1
        {
            Name             = "$ReverseLookup1.in-addr.arpa"
            DynamicUpdate = 'Secure'
            Ensure           = 'Present'
            ReplicationScope = 'Domain'
            DependsOn = '[WaitForADDomain]DscForestWait'
        }

        DnsServerADZone ReverseADZone2
        {
            Name             = "$ReverseLookup2.in-addr.arpa"
            DynamicUpdate = 'Secure'
            Ensure           = 'Present'
            ReplicationScope = 'Domain'
            DependsOn = '[WaitForADDomain]DscForestWait'
        }

        DnsRecordPtr DC1PtrRecord
        {
            Name      = "$computerName.$InternaldomainName"
            ZoneName = "$ReverseLookup1.in-addr.arpa"
            IpAddress = "$ForwardLookup1.$dc1lastoctet"
            Ensure    = 'Present'
            DependsOn = "[DnsServerADZone]ReverseADZone1"           
        }

        DnsRecordPtr DC2PtrRecord
        {
            Name      = "$DC2Name.$InternaldomainName"
            ZoneName =  "$ReverseLookup2.in-addr.arpa"
            IpAddress =  "$ForwardLookup2.$dc2lastoctet"
            Ensure    = 'Present'
            DependsOn = "[DnsServerADZone]ReverseADZone2"
        }

        DnsRecordA crlrecord
        {
            Name      = "crl"
            ZoneName  = "$ExternaldomainName"
            IPv4Address = "$icaIP"
            Ensure    = 'Present'
            DependsOn = '[DnsServerADZone]ExternalDomain'
        }

        DnsRecordA ocsprecord
        {
            Name      = "ocsp"
            ZoneName  = "$ExternaldomainName"
            IPv4Address = "$ocspIP"
            Ensure    = 'Present'
            DependsOn = '[DnsServerADZone]ExternalDomain'
        }

        DnsRecordA owa2019record1
        {
            Name      = "owa2019"
            ZoneName  = "$ExternaldomainName"
            IPv4Address  = "$ex1IP"
            Ensure    = 'Present'
            DependsOn = '[DnsServerADZone]ExternalDomain'
        }

        DnsRecordA owa2019record2
        {
            Name      = "owa2019"
            ZoneName  = "$ExternaldomainName"
            IPv4Address  = "$ex2IP"
            Ensure    = 'Present'
            DependsOn = '[DnsServerADZone]ExternalDomain'
        }

        DnsRecordA autodiscover2019record1
        {
            Name      = "autodiscover2019"
            ZoneName  = "$ExternaldomainName"
            IPv4Address  = "$ex1IP"
            Ensure    = 'Present'
            DependsOn = '[DnsServerADZone]ExternalDomain'
        }

        DnsRecordA autodiscover2019record2
        {
            Name      = "autodiscover2019"
            ZoneName  = "$ExternaldomainName"
            IPv4Address  = "$ex2IP"
            Ensure    = 'Present'
            DependsOn = '[DnsServerADZone]ExternalDomain'
        }


        DnsRecordA outlook2019record1
        {
            Name      = "outlook2019"
            ZoneName  = "$ExternaldomainName"
            IPv4Address  = "$ex1IP"
            Ensure    = 'Present'
            DependsOn = '[DnsServerADZone]ExternalDomain'
        }

        DnsRecordA outlook2019record2
        {
            Name      = "outlook2019"
            ZoneName  = "$ExternaldomainName"
            IPv4Address  = "$ex2IP"
            Ensure    = 'Present'
            DependsOn = '[DnsServerADZone]ExternalDomain'
        }

        DnsRecordA eas2019record1
        {
            Name      = "eas2019"
            ZoneName  = "$ExternaldomainName"
            IPv4Address  = "$ex1IP"
            Ensure    = 'Present'
            DependsOn = '[DnsServerADZone]ExternalDomain'
        }

        DnsRecordA eas2019record2
        {
            Name      = "eas2019"
            ZoneName  = "$ExternaldomainName"
            IPv4Address  = "$ex2IP"
            Ensure    = 'Present'
            DependsOn = '[DnsServerADZone]ExternalDomain'
        }

        DnsRecordA smtprecord1
        {
            Name      = "smtp"
            ZoneName  = "$ExternaldomainName"
            IPv4Address = "$ex1IP"
            Ensure    = 'Present'
            DependsOn = '[DnsServerADZone]ExternalDomain'
         }

        DnsRecordA smtprecord2
        {
            Name      = "smtp"
            ZoneName   = "$ExternaldomainName"
            IPv4Address = "$ex2IP"
            Ensure    = 'Present'
            DependsOn = '[DnsServerADZone]ExternalDomain'
         }
    }
}