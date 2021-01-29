param
(
	[string]$installedProducts,
	[string]$silentConfigUri,
	[string]$installerUri,
	[string]$dbServerName, 
	[string]$databaseName, 
	[string]$dbUserName, 
	[string]$dbPassword,
	[string]$ntaDBServerName,
	[string]$ntaDBName,
	[string]$ntaDBUserName,
	[string]$ntaDBPassword,
	[string]$laDBServerName,
	[string]$laDBName,
	[string]$laDBUserName,
	[string]$laDBPassword,
	[string]$appUserPassword,
	[string]$vmName,
	[string]$createDatabases
)

function Invoke-Request {
	param 
	(
		[string]$Uri,
		[string]$OutFile,
		[int]$MaximumRetryCount = 1,
		[int]$RetryIntervalSec = 10
	)

	[string]$StatusText = ""
	[int]$Tries = 0
	[bool]$Success = $false

	[Net.ServicePointManager]::SecurityProtocol = ([Net.SecurityProtocolType]::SystemDefault -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12)

	do {
		$Tries++

		try { 
			Invoke-WebRequest -Uri $Uri -OutFile $OutFile -ErrorAction Stop
			$StatusText = "Invoke-WebRequest ($Uri) completed succesfully."
			$Success = $true
		} 
		catch { 
			if ($_.Exception.Response.StatusCode) {
				$StatusCode = $_.Exception.Response.StatusCode
				$StatusCodeInt = $StatusCode.value__
				$StatusText = "Invoke-WebRequest ($Uri) return $StatusCode ($StatusCodeInt)"
			}
			else {
				$StatusText = "Invoke-WebRequest ($Uri) error $($_.Exception)"
			}
		}

		Write-Host "[$Tries/$MaximumRetryCount] $StatusText"
		if (($Success -eq $false) -and ($Tries -ne $MaximumRetryCount)) {
			Write-Host "[$Tries/$MaximumRetryCount] Waiting $RetryIntervalSec seconds for another try."
			Start-Sleep $RetryIntervalSec
		}
	} 
	while (($Success -ne $true) -and ($Tries -lt $MaximumRetryCount)) 
}

$logFile = 'C:\Windows\Temp\OrionInstallBootstrap.log'
Start-Transcript -Path $logFile

# Download the silent installer config file from Artifacts
Write-Host "Downloading silent installer config file from $silentConfigUri"; [datetime]::Now
$configfilePath = "C:\Windows\Temp\silentconfig.xml"
Invoke-Request -Uri $silentConfigUri -OutFile $configfilePath -MaximumRetryCount 3 -RetryIntervalSec 30
Write-Host "Silent installer config file has been downloaded"; [datetime]::Now

# Download the installer from Artifacts
Write-Host "Downloading installer from $installerUri"; [datetime]::Now
$installer_name = "SolarWinds-Orion-Installer.exe"
Invoke-Request -Uri $installerUri -OutFile "C:\Windows\Temp\$installer_name" -MaximumRetryCount 3 -RetryIntervalSec 30
Write-Host "Installer has been downloaded"; [datetime]::Now

# Check for NTA or LA installation
$installNta = $installedProducts -like '*NTA*'
$installLa = $installedProducts -like '*LA*'

# Replace product names for installation
$ProductToInstall = @{
    LA  = "OrionLogManager"
    ETS = "ToolsetWeb"
}
$ProductToInstall.Keys | ForEach-Object { $installedProducts = $installedProducts.Replace("$_", $ProductToInstall[$_]) } 

#update DB details
$xml = New-Object XML
$xml.Load($configfilePath)

if ($xml.SilentConfig.Host.Info.Database) {
	$dbnode = $xml.SilentConfig.Host.Info.Database	
	$dbnode.ServerName = "tcp:$dbServerName"
	$dbnode.DatabaseName = $databaseName
	$dbnode.User = $dbUserName    
	$dbnode.UserPassword = $dbPassword
	$dbnode.AccountPassword = $dbPassword
	$dbnode.CreateNewDatabase = $createDatabases
}

$plugins = $xml.SilentConfig.AppendChild($xml.CreateElement("Plugins"))
# Adding configuration for LA if it is being installed
if ($installLa) {
	write-host "Adding LA tags [ OrionLogConfiguration, StorageConfig, CreateNewDatabase, DatabaseName, ServerName, UseSQLSecurity,User, UserPassword, AccountType, Account, AccountPassword] in silent config "; [datetime]::Now
	$laDatabaseNode = $xml.SilentConfig.Host.Info.AppendChild($xml.CreateElement("OrionLogConfiguration"));
	$laStorage = $laDatabaseNode.AppendChild($xml.CreateElement("StorageConfig"));
	$laStorage.AppendChild($xml.CreateElement("CreateNewDatabase"));
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

# Adding configuration for NTA if it is being installed
if ($installNta) {
	write-host "Adding NTA tags [ OrionLogConfiguration, StorageConfig, CreateNewDatabase, DatabaseName, ServerName, UseSQLSecurity,User, UserPassword, AccountType, Account, AccountPassword] in silent config "; [datetime]::Now
	$ntaDatabaseNode = $xml.SilentConfig.Host.Info.AppendChild($xml.CreateElement("NetFlowConfiguration"));
	$ntaflowStorage = $ntaDatabaseNode.AppendChild($xml.CreateElement("FlowStorageConfig"));
	$ntaflowStorage.AppendChild($xml.CreateElement("CreateNewDatabase"));
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

# Update LA specific database details
if ($xml.SilentConfig.Host.Info.OrionLogConfiguration.StorageConfig -and $installLa) {
	Write-Host "Updating LA database section"; [datetime]::Now
	$nodeStorageConfig = $xml.SilentConfig.Host.Info.OrionLogConfiguration.StorageConfig
	$nodeStorageConfig.ServerName = 'tcp:' + $laDBServerName
	$nodeStorageConfig.DatabaseName = $laDBName
	$nodeStorageConfig.User = $laDBUserName
	$nodeStorageConfig.UserPassword = $laDBPassword
	$nodeStorageConfig.AccountType = 'NewSql'
	$nodeStorageConfig.Account = 'SolarWindsLaDatabaseUser'
	$nodeStorageConfig.AccountPassword = $laDBPassword
	$nodeStorageConfig.CreateNewDatabase = $createDatabases
	$nodeStorageConfig.UseSQLSecurity = 'True'
	Write-Host "LA Database Name " $nodeStorageConfig.DatabaseName
}

# Update NTA specific database details
if ($xml.SilentConfig.Host.Info.NetFlowConfiguration.FlowStorageConfig -and $installNta) {
	Write-Host "Updating NTA database section"; [datetime]::Now
	$nodeStorageConfig = $xml.SilentConfig.Host.Info.NetFlowConfiguration.FlowStorageConfig
	$nodeStorageConfig.ServerName = 'tcp:' + $ntaDBServerName
	$nodeStorageConfig.DatabaseName = $ntaDBName
	$nodeStorageConfig.User = $ntaDBUserName
	$nodeStorageConfig.UserPassword = $ntaDBPassword
	$nodeStorageConfig.AccountType = 'NewSql'
	$nodeStorageConfig.Account = 'SolarWindsNtaDatabaseUser'
	$nodeStorageConfig.AccountPassword = $ntaDBPassword
	$nodeStorageConfig.CreateNewDatabase = $createDatabases
	$nodeStorageConfig.UseSQLSecurity = 'True'
	Write-Host "NTA Database Name " $nodeStorageConfig.DatabaseName
}

if ($xml.SilentConfig.Host.Info.Website) {
	$nodeWebsite = $xml.SilentConfig.Host.Info.Website
	$nodeWebsite.DefaultAdminPassword = $appUserPassword
	$nodeWebsite.CertificateResolvableCN = $vmName
}

if ($xml.SilentConfig.InstallerConfiguration) {
	$node = $xml.SilentConfig.InstallerConfiguration
	$node.ProductsToInstall = $installedProducts
}

$xml.Save($configfilePath)

#create installer file
New-Item C:\Windows\Temp\installer.ps1 -ItemType file
Add-Content 'C:\Windows\Temp\installer.ps1' .\$installer_name" /s /ConfigFile=""$configfilePath"""

#Start installation
Write-Host 'Starting installation....'; [datetime]::Now
Set-Location "C:\Windows\Temp"
.\installer.ps1
Write-Host 'Installation has started'; [datetime]::Now

# Wait and check for installation to be done
$process_name = $installer_name.Substring(0, $installer_name.LastIndexOf('.'))
while (1) {
	$Solarwinds = Get-Process $process_name -ErrorAction SilentlyContinue
	if ($Solarwinds) {
		Start-Sleep 5
		Remove-Variable Solarwinds
		continue;
	}
	else {
		Write-Host "SolarWinds installer process completed"; [datetime]::Now
		Remove-Variable Solarwinds
		break;
	}
}

# Delete files created in installation process
Write-Host 'Deleting files created in installation process'; [datetime]::Now

$installer_file = "C:\Windows\Temp\installer.ps1"
if (Test-Path $installer_file) {
	Remove-Item $installer_file -Force
	Write-Host 'Silent installer file deleted'; [datetime]::Now
}

if (Test-Path $configfilePath) {
	Remove-Item $configfilePath -Force
	Write-Host 'Silent config file deleted'; [datetime]::Now
}

Write-Host 'Temporary files have been deleted'; [datetime]::Now 

Stop-Transcript

(Get-Content -Path $logFile -ReadCount 0) -replace '^Host Application:.*$' | Set-Content -Path $logFile -Force # Remove Host Application line