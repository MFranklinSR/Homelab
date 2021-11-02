Configuration WAP
{
   param
   (
        [String]$TimeZone,
        [String]$NetBiosDomain,
        [String]$ADFSServerIP,
        [String]$ExternalDomainName,
        [String]$IssuingCAName,
        [String]$RootCAName,     
        [System.Management.Automation.PSCredential]$Admincreds
 
    )
 
    Import-DscResource -Module ComputerManagementDsc

    [System.Management.Automation.PSCredential ]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${NetBiosDomain}\$($AdminCreds.UserName)", $AdminCreds.Password)
 
    Node localhost
    {
        Script AllowRemoteCopy
        {
            SetScript =
            {
                # Allow Remote Copy
                $winrmserviceitem = get-item -Path "HKLM:\Software\Policies\Microsoft\Windows\WinRm\Service" -ErrorAction 0
                $allowunencrypt = get-itemproperty -Path "HKLM:\Software\Policies\Microsoft\Windows\WinRm\Service" -Name "AllowUnencryptedTraffic" -ErrorAction 0
                $allowbasic = get-itemproperty -Path "HKLM:\Software\Policies\Microsoft\Windows\WinRm\Service" -Name "AllowBasic" -ErrorAction 0
                $firewall = Get-NetFirewallRule "FPS-SMB-In-TCP" -ErrorAction 0
                IF ($winrmserviceitem -eq $null) {New-Item -Path "HKLM:\Software\Policies\Microsoft\Windows\WinRm\" -Name "Service" -Force}
                IF ($allowunencrypt -eq $null) {New-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows\WinRM\Service\" -Name "AllowUnencryptedTraffic" -Value 1}
                IF ($allowbasic -eq $null) {New-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows\WinRM\Service\" -Name "AllowBasic" -Value 1}
                IF ($firewall -ne $null) {Enable-NetFirewallRule -Name "FPS-SMB-In-TCP"}
            }
            GetScript =  { @{} }
            TestScript = { $false}
        }

        File Certificates
        {
            Type = 'Directory'
            DestinationPath = 'C:\Certificates'
            Ensure = "Present"
            DependsOn = '[Script]AllowRemoteCopy'
        }

        TimeZone SetTimeZone
        {
            IsSingleInstance = 'Yes'
            TimeZone         = $TimeZone
        }
                
        # Install Web Application Proxy
        WindowsFeature Web-Application-Proxy
        {
            Name = 'Web-Application-Proxy'
            Ensure = 'Present'
        }

        WindowsFeature RSAT-RemoteAccess 
        { 
            Ensure = 'Present'
            Name = 'RSAT-RemoteAccess'
        }

        File CopyServiceCommunicationCertFromADFS
        {
            Ensure = "Present"
            Type = "Directory"
            Recurse = $true
            SourcePath = "\\$ADFSServerIP\c$\Certificates"
            DestinationPath = "C:\Certificates\"
            Credential = $Admincreds
            DependsOn = '[File]Certificates'
        }

        Script ConfigureWAPCertificates
        {
            SetScript =
            {
                # Create Credentials
                $LoadCreds = "$using:AdminCreds"
                $Password = $AdminCreds.Password

                # Add Host Record for Resolution
                Add-Content C:\Windows\System32\Drivers\Etc\Hosts "$using:ADFSServerIP adfs.$using:ExternalDomainName"

                #Check if ADFS Service Communication Certificate already exists if NOT Create
                $adfsthumbprint = (Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object {$_.Subject -like 'CN=adfs*'}).Thumbprint
                IF ($adfsthumbprint -eq $null) {Import-PfxCertificate -FilePath "C:\Certificates\adfs.$using:ExternalDomainName.pfx" -CertStoreLocation Cert:\LocalMachine\My -Password $Password}

                #Check if Certificate Chain Certs already exists if NOT Create
                $importrootca = (Get-ChildItem -Path Cert:\LocalMachine\Root | Where-Object {$_.Subject -like "CN=$using:RootCAName*"}).Thumbprint
                IF ($importrootca -eq $null) {Import-Certificate -FilePath "C:\Certificates\$using:RootCAName.cer" -CertStoreLocation Cert:\LocalMachine\Root}

                $importissuingca = (Get-ChildItem -Path Cert:\LocalMachine\CA | Where-Object {$_.Subject -like "CN=$using:IssuingCAName*"}).Thumbprint
                IF ($importissuingca -eq $null) {Import-Certificate -FilePath "C:\Certificates\$using:IssuingCAName.cer" -CertStoreLocation Cert:\LocalMachine\CA}
            }
            GetScript =  { @{} }
            TestScript = { $false}
            DependsOn = '[File]CopyServiceCommunicationCertFromADFS'
        }

        Script ConfigureWAPADFSTrust
        {
            SetScript =
            {
                [System.Management.Automation.PSCredential ]$Creds = New-Object System.Management.Automation.PSCredential ($using:DomainCreds.UserName), $using:DomainCreds.Password

                # Get ADFS Service Communication Certificate
                $servicethumbprint = (Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object {$_.Subject -like 'CN=adfs*'}).Thumbprint
                
                # Configure ADFS/WAP Trust
                $waphealth = Get-WebApplicationProxyHealth
                IF ($waphealth[0].HealthState -eq "Error") {Install-WebApplicationProxy –CertificateThumbprint $servicethumbprint -FederationServiceName "adfs.$using:ExternalDomainName" -FederationServiceTrustCredential $Creds}
            }
            GetScript =  { @{} }
            TestScript = { $false}
            DependsOn = '[Script]ConfigureWAPCertificates'
        }
    }
  }