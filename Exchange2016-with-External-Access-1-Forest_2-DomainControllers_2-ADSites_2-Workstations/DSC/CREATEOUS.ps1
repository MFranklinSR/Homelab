configuration CREATEOUs
{
   param
   (
        [String]$BaseDN
    )

    Import-DscResource -Module xActiveDirectory

    Node localhost
    {

       xADOrganizationalUnit AccountsOU
        {
            Name                            = "Accounts"
            Path                            = "$BaseDN"
            Description                     = "Accounts OU"
            Ensure                          = 'Present'
        }

       xADOrganizationalUnit GroupsOU
        {
            Name                            = "Groups"
            Path                            = "$BaseDN"
            Description                     = "Groups OU"
            Ensure                          = 'Present'
        }

        xADOrganizationalUnit AdminOU
        {
            Name                            = "Admin"
            Path                            = "OU=Accounts,$BaseDN"
            Description                     = "Admin OU"
            Ensure                          = 'Present'
            DependsOn = "[xADOrganizationalUnit]AccountsOU"
        }

        xADOrganizationalUnit AdminGroupsOU
        {
            Name                            = "Admin"
            Path                            = "OU=Groups,$BaseDN"
            Description                     = "Admin Groups OU"
            Ensure                          = 'Present'
            DependsOn = "[xADOrganizationalUnit]GroupsOU"
        }

        xADOrganizationalUnit EndUserOU
        {
            Name                            = "End User"
            Path                            = "OU=Accounts,$BaseDN"
            Description                     = "End User OU"
            Ensure                          = 'Present'
            DependsOn = "[xADOrganizationalUnit]AccountsOU"
        }

        xADOrganizationalUnit EndUserGroupOU
        {
            Name                            = "End User"
            Path                            = "OU=Groups,$BaseDN"
            Description                     = "End User Groups OU"
            Ensure                          = 'Present'
            DependsOn = "[xADOrganizationalUnit]GroupsOU"
        }

        xADOrganizationalUnit Office365OU
        {
            Name                            = "Office 365"
            Path                            = "OU=End User,OU=Accounts,$BaseDN"
            Description                     = "Office 365 OU"
            Ensure                          = 'Present'
            DependsOn = "[xADOrganizationalUnit]EndUserOU"
        }

        xADOrganizationalUnit Office365GroupOU
        {
            Name                            = "Office 365"
            Path                            = "OU=End User,OU=Groups,$BaseDN"
            Description                     = "Office 365 Groups OU"
            Ensure                          = 'Present'
            DependsOn = "[xADOrganizationalUnit]EndUserGroupOU"
        }

        xADOrganizationalUnit Sub1OU
        {
            Name                            = "Sub1"
            Path                            = "OU=Office 365,OU=End User,OU=Accounts,$BaseDN"
            Description                     = "Sub1 OU"
            Ensure                          = 'Present'
            DependsOn = "[xADOrganizationalUnit]Office365OU"
        }

        xADOrganizationalUnit NonOffice365OU
        {
            Name                            = "Non-Office 365"
            Path                            = "OU=End User,OU=Accounts,$BaseDN"
            Description                     = "Non-Office 365 OU"
            Ensure                          = 'Present'
            DependsOn = "[xADOrganizationalUnit]EndUserOU"
        }

        xADOrganizationalUnit ServiceOU
        {
            Name                            = "Service"
            Path                            = "OU=Accounts,$BaseDN"
            Description                     = "Service OU"
            Ensure                          = 'Present'
            DependsOn = "[xADOrganizationalUnit]AccountsOU"
        }

        xADOrganizationalUnit ServersOU
        {
            Name                            = "Servers"
            Path                            = "$BaseDN"
            Description                     = "Servers OU"
            Ensure                          = 'Present'
        }

        xADOrganizationalUnit Server2012R2OU
        {
            Name                            = "Servers2012R2"
            Path                            = "OU=Servers,$BaseDN"
            Description                     = "Server2012R2 OU"
            Ensure                          = 'Present'
            DependsOn = "[xADOrganizationalUnit]ServersOU"
        }

        xADOrganizationalUnit Server2016OU
        {
            Name                            = "Servers2016"
            Path                            = "OU=Servers,$BaseDN"
            Description                     = "Server2016 OU"
            Ensure                          = 'Present'
            DependsOn = "[xADOrganizationalUnit]ServersOU"
        }

        xADOrganizationalUnit Server2019OU
        {
            Name                            = "Servers2019"
            Path                            = "OU=Servers,$BaseDN"
            Description                     = "Server2019 OU"
            Ensure                          = 'Present'
            DependsOn = "[xADOrganizationalUnit]ServersOU"
        }
      
        xADOrganizationalUnit MaintenanceServersOU
        {
            Name                            = "Maintenance Servers"
            Path                            = "$BaseDN"
            Description                     = "Maintenance Servers OU"
            Ensure                          = 'Present'
        }

        xADOrganizationalUnit MaintenanceWorkstationsOU
        {
            Name                            = "Maintenance Workstations"
            Path                            = "$BaseDN"
            Description                     = "Maintenance Workstations OU"
            Ensure                          = 'Present'
        }

        xADOrganizationalUnit WorkstationsOU
        {
            Name                            = "Workstations"
            Path                            = "$BaseDN"
            Description                     = "Workstations OU"
            Ensure                          = 'Present'
        }

        xADOrganizationalUnit Windows10OU
        {
            Name                            = "Windows 10"
            Path                            = "OU=Workstations,$BaseDN"
            Description                     = "Windows 10 OU"
            Ensure                          = 'Present'
            DependsOn = "[xADOrganizationalUnit]WorkstationsOU"
        }

        xADOrganizationalUnit Windows7OU
        {
            Name                            = "Windows 7"
            Path                            = "OU=Workstations,$BaseDN"
            Description                     = "Workstations OU"
            Ensure                          = 'Present'
            DependsOn = "[xADOrganizationalUnit]WorkstationsOU"
        }

    }
}