Configuration WAP
{
   param
   (
        [String]$TimeZone,
        [String]$NetBiosDomain,
        [String]$ADFSServerIP,
        [String]$ExchangeVersion,
        [String]$EXServerIP,
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

        File WAPCertificates
        {
            Type = 'Directory'
            DestinationPath = 'C:\WAP-Certificates'
            Ensure = "Present"
            DependsOn = '[Script]AllowRemoteCopy'
        }

        File EXCertificates
        {
            Type = 'Directory'
            DestinationPath = 'C:\EX-Certificates'
            Ensure = "Present"
            DependsOn = '[File]WAPCertificates'
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
            SourcePath = "\\$ADFSServerIP\c$\WAP-Certificates"
            DestinationPath = "C:\WAP-Certificates\"
            Credential = $Admincreds
            DependsOn = '[File]WAPCertificates'
        }

        File CopyEXCertFromExchange
        {
            Ensure = "Present"
            Type = "Directory"
            Recurse = $true
            SourcePath = "\\$EXServerIP\c$\Certificates"
            DestinationPath = "C:\EX-Certificates\"
            Credential = $Admincreds
            DependsOn = '[File]EXCertificates'
        }

        Script ConfigureWAPCertificates
        {
            SetScript =
            {
                # Create Credentials
                $Load = "$using:AdminCreds"
                $Password = $AdminCreds.Password
                                
                # Add Host Record for Resolution
                $HostFile = Get-Content "C:\Windows\System32\Drivers\Etc\Hosts"
                $Entry = $HostFile | %{$_ -match "adfs.$using:ExternalDomainName"}
                IF ($Entry -contains $False) {

                Add-Content C:\Windows\System32\Drivers\Etc\Hosts "$using:ADFSServerIP adfs.$using:ExternalDomainName"

                }

                #Check if ADFS Service Communication Certificate already exists if NOT Import
                $adfsthumbprint = (Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object {$_.Subject -like "CN=adfs.$using:ExternalDomainName"}).Thumbprint
                IF ($adfsthumbprint -eq $null) {Import-PfxCertificate -FilePath "C:\WAP-Certificates\adfs.$using:ExternalDomainName.pfx" -CertStoreLocation Cert:\LocalMachine\My -Password $Password}

                #Check if Exchange Certificate already exists if NOT Import
                $exthumbprint = (Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object {$_.Subject -like "CN=owa$using:ExchangeVersion.$using:ExternalDomainName"}).Thumbprint
                IF ($exthumbprint -eq $null) {Import-PfxCertificate -FilePath "C:\EX-Certificates\owa$using:ExchangeVersion.$using:ExternalDomainName.pfx" -CertStoreLocation Cert:\LocalMachine\My -Password $Password}

                #Check if Certificate Chain Certs already exists if NOT Import
                $importrootca = (Get-ChildItem -Path Cert:\LocalMachine\Root | Where-Object {$_.Subject -like "CN=$using:RootCAName*"}).Thumbprint
                IF ($importrootca -eq $null) {Import-Certificate -FilePath "C:\WAP-Certificates\$using:RootCAName.cer" -CertStoreLocation Cert:\LocalMachine\Root}

                $importissuingca = (Get-ChildItem -Path Cert:\LocalMachine\CA | Where-Object {$_.Subject -like "CN=$using:IssuingCAName*"}).Thumbprint
                IF ($importissuingca -eq $null) {Import-Certificate -FilePath "C:\WAP-Certificates\$using:IssuingCAName.cer" -CertStoreLocation Cert:\LocalMachine\CA}
            }
            GetScript =  { @{} }
            TestScript = { $false}
            DependsOn = '[File]CopyServiceCommunicationCertFromADFS'
        }

        Script ConfigureWAPADFS
        {
            SetScript =
            {
                # Disable TLS 1.3
                $OS = (Get-WMIObject win32_operatingsystem).name
                IF ($OS -like '*2022*'){
                    $TLS13Key = get-item -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.3\Client" -ErrorAction 0
                    IF ($TLS13Key -eq $null) {New-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.3\" -Name "Client" -Force}
                    $DisabledByDefault = get-itemproperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.3\Client" -Name "DisabledByDefault" -ErrorAction 0
                    IF ($DisabledByDefault -eq $null) {New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.3\Client\" -Name "DisabledByDefault" -Value 1}
                    $Enabled = get-itemproperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.3\Client" -Name "Enabled" -ErrorAction 0
                    IF ($Enabled -eq $null) {New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.3\Client\" -Name "Enabled" -Value 0}
                }
                
                [System.Management.Automation.PSCredential ]$Creds = New-Object System.Management.Automation.PSCredential ($using:DomainCreds.UserName), $using:DomainCreds.Password

                # Get ADFS Service Communication Certificate
                $servicethumbprint = (Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object {$_.Subject -like "CN=adfs.$using:ExternalDomainName"}).Thumbprint
                
                # Configure ADFS/WAP Trust
                $waphealth = Get-WebApplicationProxyHealth
                IF ($waphealth[0].HealthState -eq "Error") {Install-WebApplicationProxy –CertificateThumbprint $servicethumbprint -FederationServiceName "adfs.$using:ExternalDomainName" -FederationServiceTrustCredential $Creds}

                # Get Exchange Certificate
                $exthumbprint = (Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object {$_.Subject -like "CN=owa$using:ExchangeVersion.$using:ExternalDomainName"}).Thumbprint

                # Configure Publishing Rules
                $OWAWPR = Get-WebApplicationProxyApplication | Where-Object {$_.Name -like "Outlook Web App $ExchangeVersion"}
                IF ($OWAWPR -eq $Null){
                    Add-WebApplicationProxyApplication -BackendServerUrl "https://owa$ExchangeVersion.$ExternalDomainName/owa/" -ExternalCertificateThumbprint $exthumbprint -ExternalUrl "https://owa$ExchangeVersion.$ExternalDomainName/owa/" -Name "Outlook Web App $ExchangeVersion" -ExternalPreAuthentication ADFS -ADFSRelyingPartyName "Outlook Web App $ExchangeVersion"
                }

                $ECPWPR = Get-WebApplicationProxyApplication | Where-Object {$_.Name -like "Exchange Admin Center (EAC) $ExchangeVersion"}
                IF ($ECPWPR -eq $Null){
                    Add-WebApplicationProxyApplication -BackendServerUrl "https://owa$ExchangeVersion.$ExternalDomainName/ecp/" -ExternalCertificateThumbprint $exthumbprint -ExternalUrl "https://owa$ExchangeVersion.$ExternalDomainName/ecp/" -Name "Exchange Admin Center (EAC) $ExchangeVersion" -ExternalPreAuthentication ADFS -ADFSRelyingPartyName "Exchange Admin Center (EAC) $ExchangeVersion"
                }

            }
            GetScript =  { @{} }
            TestScript = { $false}
            DependsOn = '[Script]ConfigureWAPCertificates'
        }
    }
  }