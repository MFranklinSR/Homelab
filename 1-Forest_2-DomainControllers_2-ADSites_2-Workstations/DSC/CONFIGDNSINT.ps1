configuration CONFIGDNSINT
{
   param
   (
        [String]$computerName,
        [String]$DC2Name,
        [String]$NetBiosDomain,
        [String]$InternaldomainName,
        [String]$dc1lastoctet,
        [String]$dc2lastoctet,
        [String]$domainName,
        [String]$ReverseLookup1,
        [String]$ReverseLookup2,
        [Int]$RetryIntervalSec=420,
        [System.Management.Automation.PSCredential]$Admincreds
    )

    Import-DscResource -Module DnsServerDsc
    Import-DscResource -Module ActiveDirectoryDsc

    [System.Management.Automation.PSCredential ]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${NetBiosDomain}\$($Admincreds.UserName)", $Admincreds.Password)

    Node localhost
    {
        WaitForADDomain DscForestWait
        {
            DomainName = $InternaldomainName
            Credential= $DomainCreds
            WaitTimeout = $RetryIntervalSec
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
            Name      = "$computerName.$DomainName"
            ZoneName = "$ReverseLookup1.in-addr.arpa"
            IpAddress = "$dc1lastoctet.$ReverseLookup1"
            Ensure    = 'Present'
            DependsOn = "[DnsServerADZone]ReverseADZone1"
            
           
        }

        DnsRecordPtr DC2PtrRecord
        {
            Name      = "$DC2Name.$DomainName"
            ZoneName =  "$ReverseLookup2.in-addr.arpa"
            IpAddress =  "$dc2lastoctet.$ReverseLookup1"
            Ensure    = 'Present'
            DependsOn = "[DnsServerADZone]ReverseADZone2"
        }
    }
}