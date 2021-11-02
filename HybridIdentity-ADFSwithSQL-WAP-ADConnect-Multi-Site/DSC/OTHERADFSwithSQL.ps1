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

        File Certificates
        {
            Type = 'Directory'
            DestinationPath = 'C:\Certificates'
            Ensure = "Present"
            DependsOn = '[File]MachineConfig'
        }

        File CopyCertsFromADFS
        {
            Ensure = "Present"
            Type = "Directory"
            Recurse = $true
            SourcePath = "\\$PrimaryADFSServerIP\c$\Certificates"
            DestinationPath = "C:\Certificates\"
            Credential = $Admincreds
            DependsOn = '[File]Certificates'
        }

        Script ConfigureADFSCertificates
        {
            SetScript =
            {
                $ThumbCheck1 = (Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object {$_.Subject -like "CN=adfs.$using:ExternalDomainName"}).Thumbprint
                IF ($ThumbCheck1 -eq $null) {
                # Update GPO's
                gpupdate /force

                # Create Credentials
                $Load = "$using:DomainCreds"
                $Password = $DomainCreds.Password
                $fsgmsa = 'FsGmsa$'

                # Move Crypto Keys
                $dest1 = "C:\ProgramData\Microsoft\Crypto\RSA\MachineKeys"
                $dest2 = "C:\ProgramData\Microsoft\Crypto\RSA\MachineKeys\Temp\"
                New-Item -Path $Dest2 -ItemType directory
                Get-ChildItem $dest1 -exclude "Temp" | Move-Item -Destination $dest2

                # Check if ADFS Service Communication Certificate already exists if NOT Import
                $adfsthumbprint = (Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object {$_.Subject -like "CN=adfs.$using:ExternalDomainName"}).Thumbprint
                IF ($adfsthumbprint -eq $null) {Import-PfxCertificate -FilePath "C:\Certificates\adfs.$using:ExternalDomainName.pfx" -CertStoreLocation Cert:\LocalMachine\My -Password $Password}

                # Check if Service Communication Certificate Exists
                $thumbprint = (Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object {$_.Subject -like "CN=adfs.$using:ExternalDomainName"}).Thumbprint

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
                Get-ChildItem $dest2 | Move-Item -Destination $dest1
                Remove-Item $dest2 -Force -ErrorAction 0

                # Move Crypto Keys
                $dest2 = "C:\ProgramData\Microsoft\Crypto\RSA\MachineKeys\Temp\"
                New-Item -Path $Dest2 -ItemType directory
                Get-ChildItem $dest1 -exclude "Temp" | Move-Item -Destination $dest2

                # Check if ADFS Token Signing Certificate already exists if NOT Import
                $signthumbprint = (Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object {$_.Subject -like "CN=adfs-signing.$using:ExternalDomainName"}).Thumbprint
                IF ($signthumbprint -eq $null) {Import-PfxCertificate -FilePath "C:\Certificates\adfs-signing.$using:ExternalDomainName.pfx" -CertStoreLocation Cert:\LocalMachine\My -Password $Password}

                # Check if Token Signing Certificate Exists
                $signthumbprint = (Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object {$_.Subject -like "CN=adfs-signing.$using:ExternalDomainName"}).Thumbprint

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
                Get-ChildItem $dest2 | Move-Item -Destination $dest1
                Remove-Item $dest2 -Force -ErrorAction 0
                }
            }
            GetScript =  { @{} }
            TestScript = { $false}
            DependsOn = '[File]CopyCertsFromADFS'
        }

        Script ConfigureADFS
        {
            SetScript =
            {
                $ThumbCheck1 = (Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object {$_.Subject -like "CN=adfs.$using:ExternalDomainName"}).Thumbprint
                IF ($ThumbCheck1 -eq $null) {
                # Get Service Communication Certificate
                $thumbprint = (Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object {$_.Subject -like "CN=adfs.$using:ExternalDomainName"}).Thumbprint

                # Get Token Signing Certificate
                $signthumbprint = (Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object {$_.Subject -like "CN=adfs-signing.$using:ExternalDomainName"}).Thumbprint

                Import-Module ADFS
                Add-AdfsFarmNode -GroupServiceAccountIdentifier "$using:NetBiosDomain\FsGmsa$" -CertificateThumbprint $thumbprint -SQLConnectionString "Data Source=$using:SQLHost;Initial Catalog=ADFSConfiguration;Integrated Security=True;Min Pool Size=20"
                
                # Enable Certificate Copy
                $firewall = Get-NetFirewallRule "FPS-SMB-In-TCP" -ErrorAction 0
                IF ($firewall -ne $null) {Enable-NetFirewallRule -Name "FPS-SMB-In-TCP"}
                }
            }
            GetScript =  { @{} }
            TestScript = { $false}
            PsDscRunAsCredential = $DomainCreds
            DependsOn = '[Script]ConfigureADFSCertificates'
        }
    }
}