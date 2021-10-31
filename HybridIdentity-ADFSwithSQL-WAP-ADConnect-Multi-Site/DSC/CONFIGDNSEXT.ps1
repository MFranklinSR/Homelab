configuration CONFIGDNSEXT
{
   param
   (
        [String]$computerName,
        [String]$ExternalDomainName,
        [String]$ADFSServer1IP,
        [String]$ADFSServer2IP
    )

    Import-DscResource -ModuleName DnsServerDsc

    Node localhost
    {
        DnsRecordA adfsrecord1
        {
            Name      = "adfs"
            ZoneName  = "$ExternaldomainName"
            IPv4Address = $ADFSServer1IP
            Ensure    = 'Present'
        }

        DnsRecordA adfsrecord2
        {
            Name      = "adfs"
            ZoneName  = "$ExternaldomainName"
            IPv4Address = $ADFSServer2IP
            Ensure    = 'Present'
        }
    }
}