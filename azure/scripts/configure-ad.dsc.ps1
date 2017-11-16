Configuration Main
{

    param (
        [string] $DomainName,
        [string] $DomainNetbiosName,
        [string] $DomainPassword,
        [string] $DomainFunctionalLevel
    )

    Import-DscResource -ModuleName 'PSDesiredStateConfiguration'

    WindowsFeature AD-Domain-Services
    {
        Ensure = "Present" 
        Name = "AD-Domain-Services" # Use the Name property from Get-WindowsFeature  
    }

    WindowsFeature RSAT-AD-AdminCenter
    {
        Ensure = "Present" 
        Name = "RSAT-AD-AdminCenter" # Use the Name property from Get-WindowsFeature  
    }

    xFirewall PSADRuleOutboundTCP
    {
        Name = "psad_9389_out"
        Ensure = "Present"
        DependsOn = "[xFireWall]PSRemoteAndSCCRulesInboundTCP"
        Direction = "Outbound"
        Description = "AD PowerShell Outbound"
        Profile = "Domain"
        Protocol = "TCP"
        LocalPort = ("9389")
        Action = "Allow"
        Enabled = "True"
    }

    xFirewall PSADRuleInTCP
    {
        Name = "psad_9389_in"
        Ensure = "Present"
        DependsOn = "[xFireWall]PSRemoteAndSCCRulesInboundTCP"
        Direction = "Inbound"
        Description = "AD PowerShell Outbound"
        Profile = "Domain"
        Protocol = "TCP"
        LocalPort = ("9389")
        Action = "Allow"
        Enabled = "True"
    }

    Script ADDSForest
    {
        GetScript = { 
            $domain = (Get-WmiObject -Class Win32_ComputerSystem -ComputerName . ).Name
            return @{ 'Domain' = "$domain" }
        }          
        TestScript = { 
            $domain = (Get-WmiObject -Class Win32_ComputerSystem -ComputerName . ).Name
            if( $domain -eq "WORKGROUP" )
            {
                Write-Verbose -Message ('Not Domain Joined. Domain: {0}' -f $domain)
                return $true
            }
            Write-Verbose -Message ('Domain Joined to {0}' -f $domain)
            return $false
        }
        SetScript = {
            Write-Host "[INFO] Installing AD Domain Controller"            
            Import-Module ADDSDeployment
            # Convert to secure password
            $DomainPasswordSecure = $(ConvertTo-SecureString -AsPlainText $DomainPassword -Force)
            # Configure Domain Forest
            Install-ADDSForest -DomainName $DomainName -DomainNetbiosName $DomainNetbiosName -CreateDnsDelegation:$false -DatabasePath "C:\Windows\NTDS" -DomainMode $DomainFunctionalLevel -ForestMode $DomainFunctionalLevel -InstallDns:$true -LogPath "C:\Windows\NTDS" -NoRebootOnCompletion:$false -SysvolPath "C:\Windows\SYSVOL" -SafeModeAdministratorPassword $DomainPasswordSecure -Force:$true
            # Machine Restart
        }
    }
}