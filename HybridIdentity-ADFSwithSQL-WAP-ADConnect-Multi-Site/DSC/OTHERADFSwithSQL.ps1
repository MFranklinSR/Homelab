configuration OTHERADFSwithSQL
{
   param
   (
        [String]$SQLHost,
        [String]$TimeZone,
        [String]$ExternalDomainName,
        [String]$NetBiosDomain,
        [String]$IssuingCAName,
        [String]$RootCAName,         
        [String]$PrimaryADFSServerIP,         
        [System.Management.Automation.PSCredential]$Admincreds


    )
    Import-DscResource -ModuleName xPSDesiredStateConfiguration # Used for xRemoteFile
    Import-DscResource -ModuleName ComputerManagementDsc # Used for TimeZone

    [System.Management.Automation.PSCredential ]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${NetBiosDomain}\$($Admincreds.UserName)", $Admincreds.Password)

    Node localhost
    {
        LocalConfigurationManager
        {
            RebootNodeIfNeeded = $true
        }

        WindowsFeature ADFS-Federation
        {
            Ensure = 'Present'
            Name   = 'ADFS-Federation'
        }

        TimeZone SetTimeZone
        {
            IsSingleInstance = 'Yes'
            TimeZone         = $TimeZone
        }

        File MachineConfig
        {
            Type = 'Directory'
            DestinationPath = 'C:\MachineConfig'
            Ensure = "Present"
        }

        File ADFSCertificates
        {
            Type = 'Directory'
            DestinationPath = 'C:\ADFS-Certificates'
            Ensure = "Present"
        }

        File WAPCertificates
        {
            Type = 'Directory'
            DestinationPath = 'C:\WAP-Certificates'
            Ensure = "Present"
        }

        File CopyADFSCertsFromADFS
        {
            Ensure = "Present"
            Type = "Directory"
            Recurse = $true
            SourcePath = "\\$PrimaryADFSServerIP\c$\ADFS-Certificates"
            DestinationPath = "C:\ADFS-Certificates\"
            Credential = $DomainCreds
            DependsOn = '[File]ADFSCertificates'
        }

        File CopyWAPCertsFromADFS
        {
            Ensure = "Present"
            Type = "Directory"
            Recurse = $true
            SourcePath = "\\$PrimaryADFSServerIP\c$\WAP-Certificates"
            DestinationPath = "C:\WAP-Certificates\"
            Credential = $DomainCreds
            DependsOn = '[File]WAPCertificates'
        }

        Script ADFSCertImport
        {
            SetScript =
            {
                # Create Credentials
                $ServiceCert = Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object {$_.Subject -like "CN=adfs.$using:ExternalDomainName"}
                IF ($ServiceCert -eq $null)
                {
                    # Import Service Communications Certificate
                    Import-PfxCertificate -FilePath "C:\ADFS-Certificates\adfs.$using:ExternalDomainName.pfx" -CertStoreLocation Cert:\LocalMachine\My -Exportable
                }                  

                $SigningCert = Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object {$_.Subject -like "CN=adfs-signing.$using:ExternalDomainName"}
                IF ($SigningCert -eq $null)
                {
                    # Import Signing Certificate
                    Import-PfxCertificate -FilePath "C:\ADFS-Certificates\adfs-signing.$using:ExternalDomainName.pfx" -CertStoreLocation Cert:\LocalMachine\My -Exportable
                }
            }
            GetScript =  { @{} }
            TestScript = { $false}
            PsDscRunAsCredential = $DomainCreds
            DependsOn = '[File]CopyWAPCertsFromADFS'
        }

        Script ConfigureADFS
        {
            SetScript =
            {
                $ADFSService = Get-Service adfssrv -ErrorAction 0
                IF ($ADFSService.Status -eq 'Stopped'){
                # Get Service Communication Certificate
                $ServiceThumbprint = (Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object {$_.Subject -like "CN=adfs.$using:ExternalDomainName"}).Thumbprint

                Import-Module ADFS
                Add-AdfsFarmNode -GroupServiceAccountIdentifier "$using:NetBiosDomain\FsGmsa$" -CertificateThumbprint $ServiceThumbprint -SQLConnectionString "Data Source=$using:SQLHost;Initial Catalog=ADFSConfiguration;Integrated Security=True;Min Pool Size=20"
                
                # Enable Certificate Copy
                $firewall = Get-NetFirewallRule "FPS-SMB-In-TCP" -ErrorAction 0
                IF ($firewall -ne $null) {Enable-NetFirewallRule -Name "FPS-SMB-In-TCP"}
                }
            }
            GetScript =  { @{} }
            TestScript = { $false}
            PsDscRunAsCredential = $DomainCreds
            DependsOn = '[Script]ADFSCertImport'
        }
    }
}