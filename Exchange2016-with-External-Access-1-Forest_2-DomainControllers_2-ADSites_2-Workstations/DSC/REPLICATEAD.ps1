configuration REPLICATEAD
{
   param
   (
        [String]$NetBiosDomain,
        [System.Management.Automation.PSCredential]$Admincreds
    )

    [System.Management.Automation.PSCredential ]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${NetBiosDomain}\$($Admincreds.UserName)", $Admincreds.Password)

    Node localhost
    {
        Script ReplicateAllDCs
        {
            SetScript =
            {
                # Create Exchange AD Deployment
                (Get-ADDomainController -Filter *).Name | Foreach-Object { repadmin /syncall $_ (Get-ADDomain).DistinguishedName /AdeP }
            }
            GetScript =  { @{} }
            TestScript = { $false}
            PsDscRunAsCredential = $DomainCreds
        }
    }
}