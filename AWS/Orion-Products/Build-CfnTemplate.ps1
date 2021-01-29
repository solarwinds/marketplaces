#Requires -Module Az.Compute

param 
(
    [ValidateSet("eoc", "ets", "ipam", "ncm", "npm", "nta", "la", "sam", "scm", "srm", "udt", "vman", "vnqm", "wpm")] [string] $Product,
    [string] $Windows2019AMI = "ami-074bfc9188e9e0245",
    [string] $Windows2016AMI = "ami-0fd514fcda314f145",
    [switch] $IsRc, #IsRC adds a flag to installer to use RC version
    [switch] $Debug, #Debug prints out template parameters passwed to Mustache,
    [bool] $CreateLog #Enables creation of log from Orion installation
)

$MainTemplateFileName = "cfn.json"
$Products = @('EOC', 'SAM', 'VMAN', 'SCM', 'WPM', 'NPM', 'NTA', 'NCM', 'IPAM', 'LA', 'SRM', 'UDT', 'VNQM')
$Regions = @(@{ name = "us-east-1" },
    @{ name = "us-east-2" },
    @{ name = "us-west-1" },
    @{ name = "us-west-2" },
    @{ name = "af-south-1" },
    @{ name = "ap-east-1" },
    @{ name = "ap-south-1" },
    @{ name = "ap-northeast-2" },
    @{ name = "ap-southeast-1" },
    @{ name = "ap-southeast-2" },
    @{ name = "ap-northeast-1" },
    @{ name = "ca-central-1" },
    @{ name = "eu-central-1" },
    @{ name = "eu-south-1" },
    @{ name = "eu-west-1" },
    @{ name = "eu-west-2" },
    @{ name = "eu-west-3" },
    @{ name = "eu-north-1" },
    @{ name = "me-south-1" },
    @{ name = "sa-east-1"; last = 1 })

$ProductNames = @{
    WPM  = "Web Performance Monitor"
    VNQM = "VoIP & Network Quality Manager"
    LA   = "Log Analyzer"
    NCM  = "Network Configuration Manager"
    VMAN = "Virtualization Manager"
    SRM  = "Storage Resource Monitor"
    NPM  = "Network Performance Monitor"
    NTA  = "NetFlow Traffic Analyzer"
    UDT  = "User Device Tracker"
    IPAM = "IP Address Manager"
    ETS  = "Engineers Toolset"
    SAM  = "Server & Application Monitor"
    EOC  = "Enterprise Operations Console"
    SCM  = "Server Configuration Monitor"
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

function Build-ProductTemplate($Product) {
    $Product = $Product.ToLower()
    Write-Host "Building $($Product.ToUpper())..."
    $WorkFolder = ".\$Product\templates"
    $MainTemplateFilePath = "$WorkFolder\$Product.$MainTemplateFileName"
    
    $json = [ordered]@{ 
        default          = $Product; 
        defaultToInstall = Get-ProductToInstall $Product; 
        defaultFull      = $ProductNames[$Product]; 
        defaultUpper     = $Product.ToUpper();
        allProducts      = [System.Collections.ArrayList] @();
        otherProducts    = [System.Collections.ArrayList] @();
        regions          = $Regions;
        ami2016          = $Windows2016AMI;
        ami2019          = $Windows2019AMI;
        createLog        = if($CreateLog) {1} else {0};
        isEOC            = ($Product -eq 'EOC')
    }

    if (-not $json.isEOC) {
        foreach ($Name in ($Products | Where-Object { $_ -ne 'EOC'})) {
            $json.allProducts.Add(@{ 
                    name          = $Name.ToLower(); 
                    nameToInstall = (Get-ProductToInstall $Name);
                    nameFull      = $ProductNames[$Name];
                    nameUpper     = $Name;
                    isDefault     = ($Name -eq $Product);
                }) | Out-Null
        }
        $json.allProducts[-1].last = 1

        foreach ($Name in ($Products | Where-Object { $_ –ne $Product -and $_ -ne 'EOC' })) {
            $json.otherProducts.Add(@{ 
                    name          = $Name.ToLower(); 
                    nameToInstall = (Get-ProductToInstall $Name);
                    nameFull      = $ProductNames[$Name];
                    nameUpper     = $Name;
                }) | Out-Null
        }
        $json.otherProducts[-1].last = 1
    } else {
        foreach ($Name in ($Products | Where-Object { $_ –eq $Product })) {
            $json.allProducts.Add(@{ 
                    name          = $Name.ToLower(); 
                    nameToInstall = (Get-ProductToInstall $Name);
                    nameFull      = $ProductNames[$Name];
                    nameUpper     = $Name;
                    isDefault     = ($Name -eq $Product);
                }) | Out-Null
        }
        $json.allProducts[-1].last = 1
    }

    $TemplateParameters = $json | ConvertTo-Json
    if ($Debug) {
        Write-Host "Template parameters: $TemplateParameters"
    }

    Write-Host "Processing main template and saving to $MainTemplateFilePath"
    & ".\RenderFrom-Mustache.ps1" `
        -TemplatePath ".\common\templates\$MainTemplateFileName.mustache" `
        -OutputFile $MainTemplateFilePath `
        -Parameters $TemplateParameters

    if ($IsRc) {
        $json.isRc = $true
        $TemplateParameters = $json | ConvertTo-Json
        if ($Debug) {
            Write-Host "Test template parameters: $TemplateParameters"
        }

        $MainTemplateFilePath = "$WorkFolder\$Product.test.$MainTemplateFileName"
        Write-Host "Processing main template and saving to $MainTemplateFilePath"
        & ".\RenderFrom-Mustache.ps1" `
            -TemplatePath ".\common\templates\$MainTemplateFileName.mustache" `
            -OutputFile $MainTemplateFilePath `
            -Parameters $TemplateParameters
    }
}

if ($Product.Length -ne 0) {
    Build-ProductTemplate($Product)
}
else {
    $Products | ForEach-Object -Process { Build-ProductTemplate($_) }
}
