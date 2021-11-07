configuration FIRSTADFSwithSQL
{
   param
   (
        [String]$ExchangeVersion,
        [String]$SQLHost,
        [String]$TimeZone,
        [String]$ExternalDomainName,
        [String]$NetBiosDomain,
        [String]$IssuingCAName,
        [String]$RootCAName,     
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

        File Certificates
        {
            Type = 'Directory'
            DestinationPath = 'C:\Certificates'
            Ensure = "Present"
            DependsOn = '[File]MachineConfig'
        }

        Script CreateADFSCertExport
        {
            SetScript =
            {
                # Create Credentials
                $Load = "$using:DomainCreds"
                $Password = $DomainCreds.Password
                $fsgmsa = 'FsGmsa$'

                $CertCheck = Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object {$_.Subject -like "CN=adfs.$using:ExternalDomainName"}
                IF ($CertCheck -eq $null)
                {
                    # Export Service Communication Certificate
                    $ServiceCert = Get-ChildItem -Path "C:\Certificates\adfs.$using:ExternalDomainName.pfx" -ErrorAction 0
                    IF ($ServiceCert -eq $null)
                    {
                        Get-Certificate -Template WebServer1 -SubjectName "CN=adfs.$using:ExternalDomainName" -DNSName "adfs.$using:ExternalDomainName" -CertStoreLocation "cert:\LocalMachine\My"
                        $ServiceThumbprint = (Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object {$_.Subject -like "CN=adfs.$using:ExternalDomainName"}).Thumbprint                 
                        Get-ChildItem -Path cert:\LocalMachine\my\$ServiceThumbprint | Export-PfxCertificate -FilePath "C:\Certificates\adfs.$using:ExternalDomainName.pfx" -Password $Password
                        Get-ChildItem -Path cert:\LocalMachine\my\$ServiceThumbprint | Remove-Item
                    }

                    $SigningCert = Get-ChildItem -Path "C:\Certificates\adfs-signing.$using:ExternalDomainName.pfx" -ErrorAction 0
                    IF ($SigningCert -eq $null)
                    {
                        Get-Certificate -Template WebServer1 -SubjectName "CN=adfs-signing.$using:ExternalDomainName" -DNSName "adfs-signing.$using:ExternalDomainName" -CertStoreLocation "cert:\LocalMachine\My"
                        $SigningThumbprint = (Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object {$_.Subject -like "CN=adfs-signing.$using:ExternalDomainName"}).Thumbprint                 
                        Get-ChildItem -Path cert:\LocalMachine\my\$SigningThumbprint | Export-PfxCertificate -FilePath "C:\Certificates\adfs-signing.$using:ExternalDomainName.pfx" -Password $Password
                        Get-ChildItem -Path cert:\LocalMachine\my\$SigningThumbprint | Remove-Item
                    }

                    # Export Root CA
                    $RootCert = Get-ChildItem -Path "C:\Certificates\$using:RootCAName.cer" -ErrorAction 0
                    IF ($RootCert -eq $null)
                    {
                        $RootExport = Get-ChildItem -Path cert:\Localmachine\Root\ | Where-Object {$_.Subject -like "CN=$using:RootCAName*"}
                        Export-Certificate -Cert $RootExport -FilePath "C:\Certificates\$using:RootCAName.cer" -Type CER
                    }

                    # Export Issuing CA
                    $IssueCert = Get-ChildItem -Path "C:\Certificates\$using:IssuingCAName.cer" -ErrorAction 0
                    IF ($IssueCert -eq $null)
                    {
                        $IssuingExport = Get-ChildItem -Path cert:\Localmachine\CA\ | Where-Object {$_.Subject -like "CN=$using:IssuingCAName*"}
                        Export-Certificate -Cert $IssuingExport -FilePath "C:\Certificates\$using:IssuingCAName.cer" -Type CER
                    }

                    # Move Crypto Keys
                    $dest1 = "C:\ProgramData\Microsoft\Crypto\RSA\MachineKeys"
                    $dest2 = "C:\ProgramData\Microsoft\Crypto\RSA\MachineKeys\Temp\"
                    New-Item -Path $Dest2 -ItemType directory
                    Get-ChildItem $dest1 -exclude "Temp" | Move-Item -Destination $dest2

                    # Check if ADFS Service Communication Certificate already exists if NOT Import
                    $ServiceThumbprint = (Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object {$_.Subject -like "CN=adfs.$using:ExternalDomainName"}).Thumbprint
                    IF ($ServiceThumbprint -eq $null) {Import-PfxCertificate -FilePath "C:\Certificates\adfs.$using:ExternalDomainName.pfx" -CertStoreLocation Cert:\LocalMachine\My -Password $Password}

                    # Grant FsGmsa Full Access to Service Communication Certificate Private Keys
                    Start-Sleep -s 60
                    $account = "$using:NetBiosDomain\$fsgmsa"
                    $file = Get-ChildItem C:\ProgramData\Microsoft\Crypto\RSA\MachineKeys -Exclude "Temp"
                    $fullPath=$file.FullName
                    $acl=(Get-Item $fullPath).GetAccessControl('Access')
                    $permission=$account,"Full","Allow"
                    $accessRule=new-object System.Security.AccessControl.FileSystemAccessRule $permission
                    $acl.AddAccessRule($accessRule)
                    Set-Acl $fullPath $acl

                    # Move Crypto Keys
                    Get-ChildItem $dest2 | Move-Item -Destination $dest1 -Force
                    Remove-Item $dest2 -Force -ErrorAction 0

                    # Move Crypto Keys
                    $dest2 = "C:\ProgramData\Microsoft\Crypto\RSA\MachineKeys\Temp\"
                    New-Item -Path $Dest2 -ItemType directory
                    Get-ChildItem $dest1 -exclude "Temp" | Move-Item -Destination $dest2

                    # Check if ADFS Token Signing Certificate already exists if NOT Import
                    $SigningThumbprint = (Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object {$_.Subject -like "CN=adfs-signing.$using:ExternalDomainName"}).Thumbprint
                    IF ($SigningThumbprint -eq $null) {Import-PfxCertificate -FilePath "C:\Certificates\adfs-signing.$using:ExternalDomainName.pfx" -CertStoreLocation Cert:\LocalMachine\My -Password $Password}

                    # Grant FsGmsa Full Access to Signing Certificate Private Keys
                    Start-Sleep -s 60
                    $account = "$using:NetBiosDomain\$fsgmsa"
                    $file = Get-ChildItem C:\ProgramData\Microsoft\Crypto\RSA\MachineKeys -Exclude "Temp"
                    $fullPath=$file.FullName
                    $acl=(Get-Item $fullPath).GetAccessControl('Access')
                    $permission=$account,"Full","Allow"
                    $accessRule=new-object System.Security.AccessControl.FileSystemAccessRule $permission
                    $acl.AddAccessRule($accessRule)
                    Set-Acl $fullPath $acl

                    # Move Crypto Keys
                    Get-ChildItem $dest2 | Move-Item -Destination $dest1 -Force
                    Remove-Item $dest2 -Force -ErrorAction 0
                }
            }
            GetScript =  { @{} }
            TestScript = { $false}
            DependsOn = '[File]Certificates'
        }

        Script ConfigureADFS
        {
            SetScript =
            {
                $RulesFile = Get-ChildItem -Path C:\MachineConfig\IssuanceAuthorizationRules.txt -ErrorAction 0
                IF ($RulesFile -eq $null)
                {
                # Create Issuance Authorization Rules File
                Set-Content -Path C:\MachineConfig\IssuanceAuthorizationRules.txt -Value '@RuleTemplate = "AllowAllAuthzRule"'
                Add-Content -Path C:\MachineConfig\IssuanceAuthorizationRules.txt -Value '=> issue(Type = "http://schemas.microsoft.com/authorization/claims/permit",'
                Add-Content -Path C:\MachineConfig\IssuanceAuthorizationRules.txt -Value 'Value = "true");'

                # Create Issuance Transform Rules File
                Set-Content -Path C:\MachineConfig\IssuanceTransformRules.txt -Value '@RuleName = "ActiveDirectoryUserSID"'
                Add-Content -Path C:\MachineConfig\IssuanceTransformRules.txt -Value 'c:[Type == "http://schemas.microsoft.com/ws/2008/06/identity/claims/windowsaccountname", Issuer == "AD AUTHORITY"]'
                Add-Content -Path C:\MachineConfig\IssuanceTransformRules.txt -Value '=> issue(store = "Active Directory", types = ("http://schemas.microsoft.com/ws/2008/06/identity/claims/primarysid"), query = ";objectSID;{0}", param = c.Value);'
                Add-Content -Path C:\MachineConfig\IssuanceTransformRules.txt -Value '@RuleName = "ActiveDirectoryUPN"'
                Add-Content -Path C:\MachineConfig\IssuanceTransformRules.txt -Value 'c:[Type == "http://schemas.microsoft.com/ws/2008/06/identity/claims/windowsaccountname", Issuer == "AD AUTHORITY"]'
                Add-Content -Path C:\MachineConfig\IssuanceTransformRules.txt -Value '=> issue(store = "Active Directory", types = ("http://schemas.xmlsoap.org/ws/2005/05/identity/claims/upn"), query = ";userPrincipalName;{0}", param = c.Value);'

                # Get Service Communication Certificate
                $ServiceThumbprint = (Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object {$_.Subject -like "CN=adfs.$using:ExternalDomainName"}).Thumbprint

                # Get Token Signing Certificate
                $SigningThumbprint = (Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object {$_.Subject -like "CN=adfs-signing.$using:ExternalDomainName"}).Thumbprint

                Import-Module ADFS
                Install-AdfsFarm -CertificateThumbprint $ServiceThumbprint -FederationServiceName "adfs.$using:ExternalDomainName" -GroupServiceAccountIdentifier "$using:NetBiosDomain\FsGmsa$" -SQLConnectionString "Data Source=$using:SQLHost;Initial Catalog=ADFSConfiguration;Integrated Security=True;Min Pool Size=20"
                
                # Create Relying Pary Trust Script
                [string]$IssuanceAuthorizationRules=Get-Content -Path C:\MachineConfig\IssuanceAuthorizationRules.txt
                [string]$IssuanceTransformRules=Get-Content -Path C:\MachineConfig\IssuanceTransformRules.txt

                # Create Relying Party Trusts
                Add-ADFSRelyingPartyTrust -Name "Outlook Web App $using:ExchangeVersion" -Enabled $true -Notes "This is a trust for https://owa$using:ExchangeVersion.$using:ExternalDomainName/owa" -WSFedEndpoint "https://owa$using:ExchangeVersion.$using:ExternalDomainName/owa" -Identifier "https://owa$using:ExchangeVersion.$using:ExternalDomainName/owa" -IssuanceTransformRules $IssuanceTransformRules -IssuanceAuthorizationRules $IssuanceAuthorizationRules
                Add-ADFSRelyingPartyTrust -Name "Exchange Admin Center (EAC) $using:ExchangeVersion" -Enabled $true -Notes "This is a trust for https://owa$using:ExchangeVersion.$using:ExternalDomainName/ecp" -WSFedEndpoint "https://owa$using:ExchangeVersion.$using:ExternalDomainName/ecp" -Identifier "https://owa$using:ExchangeVersion.$using:ExternalDomainName/ecp" -IssuanceTransformRules $IssuanceTransformRules -IssuanceAuthorizationRules $IssuanceAuthorizationRules

                # Turn off Certificate Auto Certificate Rollover
                Set-ADFSProperties -AutoCertificateRollover $False
                
                # Add Token Signing Certificate
                Add-AdfsCertificate -CertificateType "Token-Signing" -Thumbprint $SigningThumbprint

                # Set Token Signing Certificate
                Set-AdfsCertificate -IsPrimary -CertificateType "Token-Signing" -Thumbprint $SigningThumbprint
                
                # Remove Self-Signed Certificate
                Get-AdfsCertificate | Where-Object {$_.CertificateType -eq 'Token-Signing'} | Where-Object {$_.IsPrimary -ne 'True'} | Remove-AdfsCertificate

                # Enable Certificate Copy
                $EnableSMB = Get-NetFirewallRule "FPS-SMB-In-TCP" -ErrorAction 0
                IF ($EnableSMB -ne $null) {Enable-NetFirewallRule -Name "FPS-SMB-In-TCP"}

                # Enable Test Sign-In
                Set-AdfsProperties -EnableIdPInitiatedSignonPage $true
                }
            }
            GetScript =  { @{} }
            TestScript = { $false}
            PsDscRunAsCredential = $DomainCreds
            DependsOn = '[Script]CreateADFSCertExport'
        }
    }
}