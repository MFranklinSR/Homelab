configuration CREATESITES
{
   param
   (
        [String]$computerName,
        [String]$NamingConvention,
        [String]$BaseDN,
        [String]$Site1Prefix,
        [String]$Site2Prefix
    )

    Import-DscResource -Module xActiveDirectory

    Node localhost
    {

        xADReplicationSite Site1
        {
            Ensure = 'Present'
            Name   = "$NamingConvention-Site1"
        }

        xADReplicationSite Site2
        {
            Ensure = 'Present'
            Name   = "$NamingConvention-Site2"
        }

        xADReplicationSubnet Site1Subnet1
        {
            Name     = $Site1Prefix
            Site     = "$NamingConvention-Site1"
            DependsOn = "[xADReplicationSite]Site1"
        }

        xADReplicationSubnet Site2Subnet1
        {
            Name     = $Site2Prefix
            Site     = "$NamingConvention-Site2"
            DependsOn = "[xADReplicationSite]Site2"
        }

        xADReplicationSiteLink ChangeDefaultSiteCost
        {
            Name                          = "DEFAULTIPSITELINK"
            SitesIncluded                 = @("$NamingConvention-Site1", "$NamingConvention-Site2", "Default-First-Site-Name")
            Cost                          = 1000
            DependsOn = "[xADReplicationSubnet]Site2Subnet1"
        }

        xADReplicationSiteLink Site1andSite2
        {
            Name                          = "Site1-and-Site2"
            SitesIncluded                 = @("$NamingConvention-Site1", "$NamingConvention-Site2")
            Cost                          = 100
            ReplicationFrequencyInMinutes = 15
            Ensure                        = 'Present'
            DependsOn = "[xADReplicationSiteLink]ChangeDefaultSiteCost"
        }

        Script UpdateDNSSettings
        {
            SetScript =
            {

                # Move First Domain Controller
                $Site1DN = "CN=$using:NamingConvention-Site1,CN=Sites,CN=Configuration,$using:BaseDN"
                Move-ADDirectoryServer -Identity $using:computerName -Site $Site1DN

            }
            GetScript =  { @{} }
            TestScript = { $false}
            DependsOn = '[xADReplicationSiteLink]Site1andSite2'
        }

    }
}