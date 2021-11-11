configuration ADFSAUTH
{
   param
   (
        [String]$ExchangeVersion,
        [String]$ComputerName,
        [String]$InternaldomainName,
        [String]$ExternaldomainName,
        [String]$ADFSServerIP,                                                 
        [String]$NetBiosDomain,
        [String]$BaseDN,
        [String]$Site1DC,
        [String]$Site2DC,
        [System.Management.Automation.PSCredential]$Admincreds
    )

    [System.Management.Automation.PSCredential ]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${NetBiosDomain}\$($Admincreds.UserName)", $Admincreds.Password)

    Node localhost
    {
        LocalConfigurationManager
        {
            RebootNodeIfNeeded = $true
        }

        File CopyADFSCertsFromADFS
        {
            Ensure = "Present"
            Type = "Directory"
            Recurse = $true
            SourcePath = "\\$ADFSServerIP\c$\ADFS-Certificates"
            DestinationPath = "C:\Certificates\"
            Credential = $DomainCreds
        }

        Script ConfigureExchange2019
        {
            SetScript =
            {
                repadmin /replicate "$using:Site1DC" "$using:Site2DC" "$using:BaseDN"
                repadmin /replicate "$using:Site2DC" "$using:Site1DC" "$using:BaseDN"

                # Connect to Exchange
                $Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri "http://$using:computerName.$using:InternalDomainName/PowerShell/"
                Import-PSSession $Session

                $OrgConfig = Get-OrganizationConfig
                IF ($OrgConfig.AdfsAudienceUris -eq $Null){
                    
                    $ADFSThumbprint = Get-Content -Path C:\Certificates\ADFSThumbprint.txt
                    
                    $uris = @("https://owa$using:ExchangeVersion.$using:ExternalDomainName/owa/","https://owa$using:ExchangeVersion.$using:ExternalDomainName/ecp/")

                    Set-OrganizationConfig -AdfsIssuer "https://adfs.$using:ExternalDomainName/adfs/ls/" -AdfsAudienceUris $uris -AdfsSignCertificateThumbprint $ADFSThumbprint

                    # ADFS on FORMS off
                    Set-OwaVirtualDirectory –Identity "$using:computerName\owa (Default Web Site)" -AdfsAuthentication $true -BasicAuthentication $false -DigestAuthentication $false -FormsAuthentication $false -WindowsAuthentication $false
                    Set-EcpVirtualDirectory -Identity "$using:computerName\ecp (Default Web Site)" -AdfsAuthentication $true -BasicAuthentication $false -DigestAuthentication $false -FormsAuthentication $false -WindowsAuthentication $false
                }
            }
            GetScript =  { @{} }
            TestScript = { $false}
            PsDscRunAsCredential = $DomainCreds
            DependsOn = '[File]CopyADFSCertsFromADFS'
        }
    }
}