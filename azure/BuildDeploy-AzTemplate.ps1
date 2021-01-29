#Requires -Module Az.Compute

param 
(
    [ValidateSet("eoc", "ets", "ipam", "ncm", "npm", "nta", "la", "sam", "scm", "srm", "udt", "vman", "vnqm", "wpm")] [string] [Parameter(Mandatory = $true)] $Product,
    [string] [Parameter(Mandatory = $true)] $Password,
    [string] [alias("ResourceGroupLocation")] $Location = "westeurope",
    [string] $ParametersFile,
    [string] $DscSourceFolder = ".\common\DSC",
    [string] $ResourceGroupName,
    [string] $VNetResourceGroupName,
    [string] $VnetName,
    [string] $SubnetName,
    [string] $PublicIpResourceGroupName,
    [string] $PublicIpAddressName,
    [string] $PublicIpDns,
    [switch] $SkipDeploy,
    [switch] $BuildPackage
)

if (-not (Test-Path ".\Deploy-AzTemplate.ps1")) {
    Invoke-WebRequest "https://github.com/Azure/azure-quickstart-templates/raw/master/Deploy-AzTemplate.ps1" -UseBasicParsing -OutFile "Deploy-AzTemplate.ps1"
}
if (-not (Test-Path ".\SideLoad-AzCreateUIDefinition.ps1")) {
    Invoke-WebRequest "https://github.com/Azure/azure-quickstart-templates/raw/master/SideLoad-AzCreateUIDefinition.ps1" -UseBasicParsing -OutFile "SideLoad-AzCreateUIDefinition.ps1"
}

if (($VNetResourceGroupName -or $VnetName -or $SubnetName) -ne ($VNetResourceGroupName -and $VnetName -and $SubnetName)) {
    Write-Host "You have to provide -VNetResourceGroupName, -VnetName and -SubnetName to use an existing Virtual Network"
    exit
}

if (($PublicIpResourceGroupName -or $PublicIpAddressName -or $PublicIpDns) -ne ($PublicIpResourceGroupName -and $PublicIpAddressName -and $PublicIpDns)) {
    Write-Host "You have to provide -PublicIpResourceGroupName, -PublicIpDns and -PublicIpAddressName to use an existing Public IP address"
    exit
}

Write-Host "Building $($Product.ToUpper())..."
$Product = $Product.ToLower()
$Guid = New-Guid
$WorkFolder = ".\$Product\templates"
$DscFolder = "$WorkFolder\DSC"
$InstallerFolder = "$WorkFolder\installer"
$ConfigFolder = "$WorkFolder\config"

$MainTemplateFileName = "mainTemplate.json"
$AzureDeployParametersFileName = "azuredeploy.parameters.json"
$AzureDeployParametersFileNameExclude = "azuredeploy.parameters.*"
$UiDefinitionFileName = "createUiDefinition.json"

$MainTemplateFilePath = "$WorkFolder\$MainTemplateFileName"
$AzureDeployParametersFilePath = "$WorkFolder\$AzureDeployParametersFileName"
$UiDefinitionFilePath = "$WorkFolder\$UiDefinitionFileName"

$Products = @('EOC', 'SAM', 'VMAN', 'SCM', 'WPM', 'NPM', 'NTA', 'NCM', 'IPAM', 'LA', 'SRM', 'UDT', 'VNQM', 'ETS')
$ProductDetails = @{
    WPM  = @{ Name = "Web Performance Monitor"; Description = "Comprehensive website and web application performance monitoring from an end-user perspective" }
    VNQM = @{ Name = "VoIP & Network Quality Manager"; Description = "VoIP monitoring software designed for deep critical call QoS metrics and WAN performance insights" }
    LA   = @{ Name = "Log Analyzer"; Description = "Collect and analyze event log data to gain insight into the performance of your IT infrastructure" }
    NCM  = @{ Name = "Network Configuration Manager"; Description = "Automate multi-vendor network configuration management and compliance" }
    VMAN = @{ Name = "Virtualization Manager"; Description = "Manage virtual infrastructure, optimize performance, fix issues, and control resource sprawl" }
    SRM  = @{ Name = "Storage Resource Monitor"; Description = "Multi-vendor storage array performance, capacity, and hardware status monitoring" }
    NPM  = @{ Name = "Network Performance Monitor"; Description = "Multi-vendor network monitoring software designed to reduce network outages and improve performance" }
    NTA  = @{ Name = "NetFlow Traffic Analyzer"; Description = "Multi-vendor network flow (NetFlow, sFlow, J-Flow, IPFIX, etc.) traffic analyzer and bandwidth monitoring software" }
    UDT  = @{ Name = "User Device Tracker"; Description = "Network device tracking software that can locate users and devices on your network and manage their connectivity" }
    IPAM = @{ Name = "IP Address Manager"; Description = "Track and manage IP addresses and DNS and DHCP resources, helping you save time and prevent errors" }
    ETS  = @{ Name = "Engineer's Toolset"; Description = "SolarWinds® Engineer’s Toolset (ETS) helps you monitor and troubleshoot your network with the most trusted tools in network management." }
    SAM  = @{ Name = "Server & Application Monitor"; Description = "SolarWinds Server & Application Monitor (SAM) monitors your applications and their supporting infrastructure, whether they run on-premises, in the cloud, or in a hybrid environment. Automatically discover your dependencies, identify slow applications, and pinpoint root cause issues." }
    EOC  = @{ Name = "Enterprise Operations Console"; Description = "Unified visibility of status and performance of geographically distributed networks and systems" }
    SCM  = @{ Name = "Server Configuration Monitor"; Description = "Detect, alert, and track configuration changes to servers, applications, and databases - including who made the change, what changed, and if it affected performance." }
}

$ProductToInstall = @{
    LA  = "OrionLogManager"
    ETS = "ToolsetWeb"
}

function Get-ProductToInstall {
    param (
        $Product
    )

    if ($ProductToInstall.ContainsKey($Product)) {
        return $ProductToInstall[$Product]
    }
    else {
        return $Product.ToUpper()
    }
}

$Pids = @{
    WPM  = "ccc98a6a-52d7-5732-b5f2-b7b65c1e5f64"
    VNQM = "734e7dc9-3598-5246-bca1-7c6106b85a7b"
    LA   = "c4e6c6de-2caf-5d0e-b7a2-b8a922c82980"
    NCM  = "f8dff75c-61ff-5e7b-918e-dabfd5fce8e9"
    VMAN = "0414b32b-e704-53e7-9c5c-b229f2466c39"
    SRM  = "42788bdd-019f-5fb4-b396-79f750ea55bd"
    NPM  = "0ddbda9d-a07e-515d-a763-91d5a32c3485"
    NTA  = "d85d5c4f-1d76-59fb-bb1b-f42d010d0f88"
    UDT  = "ec90767a-8959-5706-9ce1-3191f99f1dd2"
    IPAM = "1b9cde35-7d9e-5169-8a81-ed3e6b594c5e"
    ETS  = "7e7320b1-2d07-5d66-98d1-c0082eff0a0a"
    SAM  = "1a25ce3f-5e14-5bd8-8e9b-70b7933b7ab4"
    EOC  = "4a8bd992-b256-5f66-aac1-cdddf174c21f"
    SCM  = "ee45e73f-5db8-5831-9a58-52aa236b27bb"
}

if (-not (Test-Path ".\common\installer\SolarWinds-Orion-Installer.exe")) {
    Write-Host "Please put SolarWinds-Orion-Installer.exe file into '.\common\installer\' folder."
    exit
}

if (-not $ResourceGroupName) {
    $ResourceGroupName = "rg-test-$Product"
}
Write-Host "Resource Group: $ResourceGroupName"

Write-Host "Creating a folder structure..."
$FoldersToCheck = $DscFolder, $InstallerFolder, $ConfigFolder
foreach ($FolderToCheck in $FoldersToCheck) {
    if (-not (Test-Path $FolderToCheck)) {
        New-Item $FolderToCheck -ItemType "Directory"
    }    
}

Write-Host "Creating DSC archives..."
if (Test-Path $DscSourceFolder) {
    $DscSourceFilePaths = @(Get-ChildItem $DscSourceFolder -File -Filter '*.ps1' | ForEach-Object -Process { $_.FullName })
    foreach ($DscSourceFilePath in $DscSourceFilePaths) {
        $DscZipFileName = (Split-Path $DSCSourceFilePath -Leaf).Split(".")[0] + ".zip"
        $DscArchiveFilePath = "$DscFolder\$DscZipFileName"
        Write-Host "Creating and copying DSC configurations to $DscArchiveFilePath ..."
        Publish-AzVMDscConfiguration $DscSourceFilePath -OutputArchivePath $DscArchiveFilePath -Force -Verbose
    }
}

Write-Host "Copying installers to $WorkFolder\installer..."
Copy-Item -Path ".\common\installer\*.exe" -Destination $InstallerFolder -Recurse -Force

Write-Host "Copying provisioning scripts to $WorkFolder..."
Copy-Item -Path ".\common\provisioning\*" -Destination $WorkFolder -Recurse -Force

Write-Host "Copying config filesto $WorkFolder\config..."
Copy-Item -Path ".\common\config\*" -Destination $ConfigFolder -Recurse -Force

$json = [ordered]@{ 
    pid              = $Pids[$Product]; 
    product          = $Product;
    productToInstall = Get-ProductToInstall $Product; 
    productFull      = $ProductDetails[$Product].Name; 
    productUpper     = $Product.ToUpper();
    productDescription = $ProductDetails[$Product].Description
    allProducts      = [System.Collections.ArrayList] @();
    otherProducts    = [System.Collections.ArrayList] @();
    productsWithDbs  = [System.Collections.ArrayList] @();
    isEOC            = ($Product -eq 'EOC');
} 

if (-not $json.isEOC) {
    foreach ($Name in ($Products | Where-Object { $_ -ne 'EOC' })) {
        $json.allProducts.Add(@{ 
                name          = $Name.ToLower(); 
                nameToInstall = (Get-ProductToInstall $Name);
                nameFull      = $ProductDetails[$Name].Name;
                nameUpper     = $Name;
                isDefault     = ($Name -eq $Product);
            }) | Out-Null
    }
    $json.allProducts[-1].last = 1

    foreach ($Name in ($Products | Where-Object { $_ -ne $Product -and $_ -ne 'EOC' })) {
        $json.otherProducts.Add(@{ 
                name          = $Name.ToLower(); 
                nameToInstall = (Get-ProductToInstall $Name);
                nameFull      = $ProductDetails[$Name].Name;
                nameUpper     = $Name;
                nameDescription = $ProductDetails[$Name].Description
            }) | Out-Null
    }
    $json.otherProducts[-1].last = 1

    foreach ($Name in ($Products | Where-Object { $_ -eq 'NTA' -or $_ -eq 'LA' })) {
        $json.productsWithDbs.Add(@{ 
                name          = $Name.ToLower(); 
                nameToInstall = (Get-ProductToInstall $Name);
                nameFull      = $ProductDetails[$Name].Name;
                nameUpper     = $Name;
                isCurrent     = $Name -eq $Product;
            }) | Out-Null
    }
    $json.productsWithDbs[-1].last = 1
} 

$TemplateParameters = $json | ConvertTo-Json
Write-Host "Template parameters: $TemplateParameters"
Write-Host "Processing UI definition template and saving to $UiDefinitionFilePath"
& ".\Build-Template.ps1" -TemplatePath ".\common\templates\$UiDefinitionFileName.mustache" -OutputFile $UiDefinitionFilePath -Parameters $TemplateParameters

Write-Host "Processing main template and saving to $MainTemplateFilePath"
& ".\Build-Template.ps1" -TemplatePath ".\common\templates\$MainTemplateFileName.mustache" -OutputFile $MainTemplateFilePath -Parameters $TemplateParameters

if ($BuildPackage) {
    Write-Host "Building a deployment package..."
    $outputPath = ".\.build\$Product\"
    if (-not (Test-Path $outputPath)) {
        New-Item $outputPath -ItemType "Directory"
    }

    $date = Get-Date -Format "yyyy_MM_dd"
    Get-ChildItem -Path $WorkFolder -Exclude $AzureDeployParametersFileNameExclude |
    Compress-Archive -DestinationPath "$outputPath\$Product-$date.zip" -Force
    exit
}

if ($ParametersFile) {
    #Copy-Item -Path $ParametersFile -Destination $AzureDeployParametersFilePath
}
else {
    $jsonParam = [ordered]@{ 
        location      = $Location; 
        product       = $Product;
        password      = $Password; 
        resourceGroup = $ResourceGroupName;
    } 

    if ($Product -eq 'nta' -or $Product -eq 'la') {
        $jsonParam.additionalDatabase = true
    }

    if ($VNetResourceGroupName) {
        $jsonParam.existingVnet = @{ vnet = $VnetName; subnet = $SubnetName; resourceGroup = $VNetResourceGroupName; }
    }
    if ($PublicIpResourceGroupName) {
        jsonParam.existingIp = @{ ipName = $PublicIpAddressName; ipDns = $PublicIpDns; resourceGroup = $PublicIpResourceGroupName; }
    }

    $OptionParameters = $jsonParam | ConvertTo-Json

    Write-Host "Parameters: $OptionParameters"
    Write-Host "Processing deployment parameters and saving to $AzureDeployParametersFilePath"
    & ".\Build-Template.ps1" -TemplatePath  ".\common\templates\$AzureDeployParametersFileName.mustache" `
        -OutputFile $AzureDeployParametersFilePath `
        -Parameters $OptionParameters
}

if ($SkipDeploy) {
    Write-Host "Configuration for $Product has been created"
    Write-Host "Skipping deployment..."
    exit
}

Write-Host "Starting deployment..."
& ".\Deploy-AzTemplate.ps1" -ArtifactStagingDirectory $WorkFolder -Location $Location -ResourceGroupName $ResourceGroupName -TemplateParametersFile $(if ($ParametersFile) { $ParametersFile } else { $AzureDeployParametersFilePath })
