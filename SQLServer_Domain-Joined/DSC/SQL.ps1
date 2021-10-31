Configuration SQL
{
   param
   (
        [String]$NetBiosDomain,
        [String]$SQLSASUrl,
        [System.Management.Automation.PSCredential]$Admincreds
    )
 
    Import-DscResource -ModuleName ComputerManagementDsc # Used for TimeZone
    Import-DscResource -ModuleName SqlServerDsc # Used for SQL
    Import-DscResource -ModuleName xStorage # Used for ISO
    Import-DscResource -ModuleName xPSDesiredStateConfiguration # Used for xRemote

    [System.Management.Automation.PSCredential ]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${NetBiosDomain}\$($AdminCreds.UserName)", $AdminCreds.Password)
 
    Node localhost
    {
        Registry SchUseStrongCrypto
        {
            Key                         = 'HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319'
            ValueName                   = 'SchUseStrongCrypto'
            ValueType                   = 'Dword'
            ValueData                   =  '1'
            Ensure                      = 'Present'
        }

        Registry SchUseStrongCrypto64
        {
            Key                         = 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\.NETFramework\v4.0.30319'
            ValueName                   = 'SchUseStrongCrypto'
            ValueType                   = 'Dword'
            ValueData                   =  '1'
            Ensure                      = 'Present'
        }

        WindowsFeature 'NetFramework45'
        {
            Name   = 'NET-Framework-45-Core'
            Ensure = 'Present'
        }

        xWaitforDisk Disk2
        {
             DiskId = 2
             RetryIntervalSec = 60
             RetryCount = 60
        }

        xDisk SVolume
        {
             DiskId = 2
             DriveLetter = 'S'
             DependsOn = '[xWaitForDisk]Disk2'
        }
        
        xWaitforVolume WaitForSVolume
        {
             DriveLetter = 'S'
             RetryIntervalSec = 60
             RetryCount = 60
        }

        xWaitforDisk Disk3
        {
             DiskId = 3
             RetryIntervalSec = 60
             RetryCount = 60
        }

        xDisk LVolume
        {
             DiskId = 3
             DriveLetter = 'L'
             DependsOn = '[xWaitForDisk]Disk3'
        }
        
        xWaitforVolume WaitForLVolume
        {
             DriveLetter = 'L'
             RetryIntervalSec = 60
             RetryCount = 60
        }

        File MachineConfig
        {
            Type = 'Directory'
            DestinationPath = 'C:\MachineConfig'
            Ensure = "Present"
        }

        File SQLSoftware
        {
            Type = 'Directory'
            DestinationPath = 'C:\SQLSoftware'
            Ensure = "Present"
        }

        File SQLDatabase
        {
            Type = 'Directory'
            DestinationPath = 'S:\SQLDatabases'
            Ensure = "Present"
        }

        File SQLLogs
        {
            Type = 'Directory'
            DestinationPath = 'L:\SQLLogs'
            Ensure = "Present"
        }

        xRemoteFile SSMS
        {
            DestinationPath = 'C:\SQLSoftware\SSMS-Setup-ENU.exe'
            Uri             = "https://aka.ms/SSMSFullSetup"
            UserAgent       = "[Microsoft.PowerShell.Commands.PSUserAgent]::InternetExplorer"
            DependsOn =    "[File]SQLSoftware"
        }

        xRemoteFile SqlDownload
        {
            DestinationPath = "C:\SQLSoftware\SQL.iso"
            Uri             = "$SQLSASUrl"
            UserAgent       = "[Microsoft.PowerShell.Commands.PSUserAgent]::InternetExplorer"
            DependsOn =    "[File]SQLSoftware"
        }

        xMountImage MountSQLISO
        {
            ImagePath   = 'C:\SQLSoftware\SQL.iso'
            DriveLetter = 'I'
            DependsOn = '[xRemoteFile]SqlDownload'
        }

        xWaitForVolume WaitForISO
        {
            DriveLetter      = 'I'
            RetryIntervalSec = 5
            RetryCount       = 10
            DependsOn = '[xMountImage]MountSQLISO'
        }

        SqlSetup 'InstallDefaultInstance'
        {
            InstanceName        = 'MSSQLSERVER'
            Features            = 'SQLENGINE'
            SourcePath          = 'I:\'
            SQLSysAdminAccounts = @('Administrators')
            DependsOn           = '[xWaitForVolume]WaitForISO'
            SQLUserDBDir        = 'S:\SQLDatabases'
            SQLUserDBLogDir     = 'L:\SQLLogs'
          }

        Script InstallSQLManagementStudio
        {
            SetScript =
            {
                # Install SQL Management Studio
                C:\SQLSoftware\SSMS-Setup-ENU.exe /install /quiet /norestart

                $EnableSQL = Get-NetFirewallRule "SQL-In-TCP" -ErrorAction 0
                IF ($EnableSQL -eq $null) {New-NetFirewallRule -DisplayName "SQL-In-TCP" -Direction Inbound -LocalPort 1433 -Protocol TCP -Action Allow}

            }
            GetScript =  { @{} }
            TestScript = { $false}
            DependsOn = '[xRemoteFile]SSMS'
        }

        TimeZone SetTimeZone
        {
            IsSingleInstance = 'Yes'
            TimeZone         = 'Eastern Standard Time'
        }
     }
  }