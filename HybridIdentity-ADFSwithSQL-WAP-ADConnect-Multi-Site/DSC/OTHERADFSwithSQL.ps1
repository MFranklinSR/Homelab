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
            Credential = $DomainCreds
            DependsOn = '[File]Certificates'
        }

        Script ADFSCertImport
        {
            SetScript =
            {
                # Create Credentials
                $Load = "$using:DomainCreds"
                $Password = $DomainCreds.Password
                $fsgmsa = 'FsGmsa$'

                $ServiceCert = Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object {$_.Subject -like "CN=adfs.$using:ExternalDomainName"}
                IF ($ServiceCert -eq $null)
                {
                    # Get Old Files
                    $Oldfiles = Get-ChildItem C:\ProgramData\Microsoft\Crypto\RSA\MachineKeys
                    $OldFileNames = @()
                    foreach ($OldFile in $OldFiles){
                        $OldFileNames += Get-ChildItem C:\ProgramData\Microsoft\Crypto\RSA\MachineKeys -Name $OldFile.Name
                    }

                    # Import Service Communications Certificate
                    Import-PfxCertificate -FilePath "C:\Certificates\adfs.$using:ExternalDomainName.pfx" -CertStoreLocation Cert:\LocalMachine\My -Password $Password -Exportable

                    # Get New Files
                    $Newfiles = Get-ChildItem C:\ProgramData\Microsoft\Crypto\RSA\MachineKeys
                    $NewFileNames = @()
                    foreach ($NewFile in $NewFiles){
                        $NewFileNames += Get-ChildItem C:\ProgramData\Microsoft\Crypto\RSA\MachineKeys -Name $NewFile.Name
                    }

                    # Get New Cert Hash
                    $DeltaFile = Compare-Object $OldFileNames $NewFileNames

                    # Add Private Key Permissions
                    $account = "$using:NetBiosDomain\$fsgmsa"
                    $FullPath = "C:\ProgramData\Microsoft\Crypto\RSA\MachineKeys"+"\"+$DeltaFile.InputObject                    
                    $acl=(Get-Item $fullPath).GetAccessControl('Access')
                    $permission=$account,"Full","Allow"
                    $accessRule=new-object System.Security.AccessControl.FileSystemAccessRule $permission
                    $acl.AddAccessRule($accessRule)
                    Set-Acl $fullPath $acl
                }                  

                $SigningCert = Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object {$_.Subject -like "CN=adfs-signing.$using:ExternalDomainName"}
                IF ($SigningCert -eq $null)
                {

                    # Get Old Files
                    $Oldfiles = Get-ChildItem C:\ProgramData\Microsoft\Crypto\RSA\MachineKeys
                    $OldFileNames = @()
                    foreach ($OldFile in $OldFiles){
                        $OldFileNames += Get-ChildItem C:\ProgramData\Microsoft\Crypto\RSA\MachineKeys -Name $OldFile.Name
                    }

                    # Import Signing Certificate
                    Import-PfxCertificate -FilePath "C:\Certificates\adfs-signing.$using:ExternalDomainName.pfx" -CertStoreLocation Cert:\LocalMachine\My -Password $Password -Exportable

                    # Get New Files
                    $Newfiles = Get-ChildItem C:\ProgramData\Microsoft\Crypto\RSA\MachineKeys
                    $NewFileNames = @()
                    foreach ($NewFile in $NewFiles){
                        $NewFileNames += Get-ChildItem C:\ProgramData\Microsoft\Crypto\RSA\MachineKeys -Name $NewFile.Name
                    }

                    # Get New Cert Hash
                    $DeltaFile = Compare-Object $OldFileNames $NewFileNames

                    # Add Private Key Permissions
                    $account = "$using:NetBiosDomain\$fsgmsa"
                    $FullPath = "C:\ProgramData\Microsoft\Crypto\RSA\MachineKeys"+"\"+$DeltaFile.InputObject                    
                    $acl=(Get-Item $fullPath).GetAccessControl('Access')
                    $permission=$account,"Full","Allow"
                    $accessRule=new-object System.Security.AccessControl.FileSystemAccessRule $permission
                    $acl.AddAccessRule($accessRule)
                    Set-Acl $fullPath $acl
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