param
(
    [string] $installerParameter
)

Start-Transcript -Path C:\cfn\OrionInstallBootstrap.Log

Add-Type -AssemblyName System.Web # required for password generation

$TemplateParametersXmlFileLocation = "C:\cfn\artifacts\InstallerConfig.xml"
$templateParameters = Import-Clixml -Path $TemplateParametersXmlFileLocation

$artifactsFolder = "C:\cfn\artifacts"
$configfilePath = "$artifactsFolder\standard.xml"
$installerFile = "$artifactsFolder\solarwindInstaller.ps1"

$xml = New-Object XML
$xml.Load($configfilePath)
$ntaproduct = $templateParameters['ntaproduct']
$laproduct = $templateParameters['laproduct']
$plugins = $xml.SilentConfig.AppendChild($xml.CreateElement("Plugins"))
# Below code add xml tag in silent config for holding LA database details.
if (![string]::IsNullOrEmpty($laproduct)) {
    write-host "Adding la related tags [ OrionLogConfiguration, StorageConfig, CreateNewDatabase, DatabaseName, ServerName, UseSQLSecurity,User, UserPassword, AccountType, Account, AccountPassword] in silent config "; [datetime]::Now
    $laDatabaseNode = $xml.SilentConfig.Host.Info.AppendChild($xml.CreateElement("OrionLogConfiguration"));
    $laStorage = $laDatabaseNode.AppendChild($xml.CreateElement("StorageConfig"));
    $laCreateNewDatabaseNode = $laStorage.AppendChild($xml.CreateElement("CreateNewDatabase"));
    $laStorage.AppendChild($xml.CreateElement("DatabaseName"));
    $laStorage.AppendChild($xml.CreateElement("ServerName"));
    $laStorage.AppendChild($xml.CreateElement("UseSQLSecurity"));
    $laStorage.AppendChild($xml.CreateElement("User"));
    $laStorage.AppendChild($xml.CreateElement("UserPassword"));
    $laStorage.AppendChild($xml.CreateElement("AccountType"));
    $laStorage.AppendChild($xml.CreateElement("Account"));
    $laStorage.AppendChild($xml.CreateElement("AccountPassword"));
    $plugin = $plugins.AppendChild($xml.CreateElement("Plugin"))
    $plugin.SetAttribute("FactoryType", "SolarWinds.ConfigurationWizard.Plugin.LogMgmt.SilentConfigureFactory");
    $plugin.SetAttribute("Assembly", "SolarWinds.ConfigurationWizard.Plugin.LogMgmt");
}

# Below code add xml tag in silent config for holding NTA database details.
if (![string]::IsNullOrEmpty($ntaproduct)) {
    write-host "Adding NTA related tags [ OrionLogConfiguration, StorageConfig, CreateNewDatabase, DatabaseName, ServerName, UseSQLSecurity,User, UserPassword, AccountType, Account, AccountPassword] in silent config "; [datetime]::Now
    $ntaDatabaseNode = $xml.SilentConfig.Host.Info.AppendChild($xml.CreateElement("NetFlowConfiguration"));
    $ntaflowStorage = $ntaDatabaseNode.AppendChild($xml.CreateElement("FlowStorageConfig"));
    $laCreateNewDatabaseNode = $ntaflowStorage.AppendChild($xml.CreateElement("CreateNewDatabase"));
    $ntaflowStorage.AppendChild($xml.CreateElement("DatabaseName"));
    $ntaflowStorage.AppendChild($xml.CreateElement("ServerName"));
    $ntaflowStorage.AppendChild($xml.CreateElement("UseSQLSecurity"));
    $ntaflowStorage.AppendChild($xml.CreateElement("User"));
    $ntaflowStorage.AppendChild($xml.CreateElement("UserPassword"));
    $ntaflowStorage.AppendChild($xml.CreateElement("AccountType"));
    $ntaflowStorage.AppendChild($xml.CreateElement("Account"));
    $ntaflowStorage.AppendChild($xml.CreateElement("AccountPassword"));
    $plugin = $plugins.AppendChild($xml.CreateElement("Plugin"))
    $plugin.SetAttribute("FactoryType", "SolarWinds.ConfigurationWizard.Plugin.NetFlow.SilentMode.NetFlowSilentConfigureFactory");
    $plugin.SetAttribute("Assembly", "SolarWinds.ConfigurationWizard.Plugin.NetFlow");
}

#Update Orion specific database details
if ($xml.SilentConfig.Host.Info.Database) {
    write-host "Updating Orion database section"; [datetime]::Now
    $dbnode = $xml.SilentConfig.Host.Info.Database	
    $dbnode.ServerName = 'tcp:' + $templateParameters['dbServerName']
    $dbnode.DatabaseName = $templateParameters['databaseName']
    $dbnode.User = $templateParameters['dbUserName']
    $dbnode.UserPassword = $templateParameters['dbPassword']
    $dbnode.AccountPassword = $templateParameters['dbPassword']
}

#Update LA specific database details
if ($xml.SilentConfig.Host.Info.OrionLogConfiguration.StorageConfig -and (![string]::IsNullOrEmpty($laproduct))) {
    write-host "Updating LA database section"; [datetime]::Now
    $nodeStorageConfig = $xml.SilentConfig.Host.Info.OrionLogConfiguration.StorageConfig
    $nodeStorageConfig.ServerName = 'tcp:' + $templateParameters['dbServerName']
    $nodeStorageConfig.DatabaseName = -join ((65..90) + (97..122) | Get-Random -Count 5 | % { [char]$_ }) + 'laDB'
    $nodeStorageConfig.User = $templateParameters['dbUserName']
    $nodeStorageConfig.UserPassword = $templateParameters['dbPassword']
    $nodeStorageConfig.AccountType = 'NewSql'
    $nodeStorageConfig.Account = 'SolarWindsLADBUser'
    $nodeStorageConfig.CreateNewDatabase = 'true'
    $nodeStorageConfig.UseSQLSecurity = 'true'
    $nodeStorageConfig.AccountPassword = $templateParameters['dbPassword']
    write-host "LA Database Name "  $nodeStorageConfig.DatabaseName
}

#Update NTA specific database details
if ($xml.SilentConfig.Host.Info.NetFlowConfiguration.FlowStorageConfig -and (![string]::IsNullOrEmpty($ntaproduct))) {
    write-host "Updating NTA database section"; [datetime]::Now
    $nodeStorageConfig = $xml.SilentConfig.Host.Info.NetFlowConfiguration.FlowStorageConfig
    $nodeStorageConfig.ServerName = 'tcp:' + $templateParameters['dbServerName']
    $nodeStorageConfig.DatabaseName = -join ((65..90) + (97..122) | Get-Random -Count 5 | % { [char]$_ }) + 'ntaDB'
    $nodeStorageConfig.User = $templateParameters['dbUserName']
    $nodeStorageConfig.UserPassword = $templateParameters['dbPassword']
    $nodeStorageConfig.AccountType = 'NewSql'
    $nodeStorageConfig.Account = 'SolarWindsNtaDatabaseUser'
    $nodeStorageConfig.CreateNewDatabase = 'true'
    $nodeStorageConfig.UseSQLSecurity = 'true'
    $nodeStorageConfig.AccountPassword = $templateParameters['dbPassword']
    write-host "NTA Database Name "  $nodeStorageConfig.DatabaseName
}

if ($xml.SilentConfig.Host.Info.Website) {
    $nodeWebsite = $xml.SilentConfig.Host.Info.Website
    $nodeWebsite.DefaultAdminPassword = $templateParameters['appUserPassword']
    $nodeWebsite.CertificateResolvableCN = $Env:COMPUTERNAME
}
if ($xml.SilentConfig.InstallerConfiguration) {
    $list = New-Object Collections.Generic.List[String]
    $node = $xml.SilentConfig.InstallerConfiguration
    $eocproduct = $templateParameters['eocproduct']
    $samproduct = $templateParameters['samproduct']
    $ipamproduct = $templateParameters['ipamproduct']
    $ncmproduct = $templateParameters['ncmproduct']
    $npmproduct = $templateParameters['npmproduct']
    $scmproduct = $templateParameters['scmproduct']
    $udtproduct = $templateParameters['udtproduct']
    $vmanproduct = $templateParameters['vmanproduct']
    $vnqmproduct = $templateParameters['vnqmproduct']
    $srmproduct = $templateParameters['srmproduct']
    $wpmproduct = $templateParameters['wpmproduct']
    $ntaproduct = $templateParameters['ntaproduct']
    $laproduct = $templateParameters['laproduct']
	
    if (![string]::IsNullOrEmpty($eocproduct)) {
        $list.Add($eocproduct)
    }

    if (![string]::IsNullOrEmpty($samproduct)) {
        $list.Add($samproduct)
    }
    if (![string]::IsNullOrEmpty($ipamproduct)) {
        $list.Add($ipamproduct)
    }
    if (![string]::IsNullOrEmpty($ncmproduct)) {
        $list.Add($ncmproduct)
    }
    if (![string]::IsNullOrEmpty($npmproduct)) {
        $list.Add($npmproduct)
    }
    if (![string]::IsNullOrEmpty($scmproduct)) {
        $list.Add($scmproduct)
    }
    if (![string]::IsNullOrEmpty($udtproduct)) {
        $list.Add($udtproduct)
    }
    if (![string]::IsNullOrEmpty($vmanproduct)) {
        $list.Add($vmanproduct)
    }
    if (![string]::IsNullOrEmpty($vnqmproduct)) {
        $list.Add($vnqmproduct)
    }
    if (![string]::IsNullOrEmpty($srmproduct)) {
        $list.Add($srmproduct)
    }
    if (![string]::IsNullOrEmpty($wpmproduct)) {
        $list.Add($wpmproduct)
    }
    if (![string]::IsNullOrEmpty($ntaproduct)) {
        $list.Add($ntaproduct)
    }
    if (![string]::IsNullOrEmpty($laproduct)) {
        $list.Add($laproduct)
    }

    $productsList = ($list) -join ","
    Write-Host 'Products to install list : ' $productsList
    $node.ProductsToInstall = $productsList
}

Start-Sleep 5
$xml.Save($configfilePath)
Write-Host 'Configuration file updated....'; [datetime]::Now
Write-Host 'Creating CheckHealthScript Task ....'; [datetime]::Now

#Creating new User with user name 'orionadmin' through which schedular task will be created and run using that user.
$password = [System.Web.Security.Membership]::GeneratePassword(14, 2)
net user 'orionadmin' $password /add /comment:"orion  installer" /fullname:"Orion Admin" /passwordchg:NO
net localgroup Administrators /add 'orionadmin'
Write-Host 'User (orionadmin) Added to Administrators'

$scheduledTime = (Get-Date).AddMinutes(1).ToString("HH:mm")
schtasks /CREATE /TN CheckHealthScript /TR "powershell.exe -ExecutionPolicy Unrestricted  -file '$installerFile' $installerParameter" /RL HIGHEST /SC ONCE /ST $scheduledTime /RU 'orionadmin' /RP $password

Write-Host 'Created CheckHealthScript Task ....'; [datetime]::Now
Stop-Transcript
