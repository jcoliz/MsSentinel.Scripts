<#
.SYNOPSIS
Deploys a Microsoft Sentinel solution to an existing workspace.

.DESCRIPTION
This script deploys a Sentinel solution template to an existing Log Analytics
workspace and resource group. The solution template must be located in a
Package subdirectory within the partition directory.

.PARAMETER TemplateRoot
The root directory path containing solution template subdirectories. The script
will look for mainTemplate.json in <TemplateRoot>/<Partition>/Package/.
Defaults to C:\GitHub\Azure-Sentinel\Solutions.

.PARAMETER Partition
The partition identifier that also serves as the solution template directory name
(e.g., 'dev', 'test', 'prod'). The mainTemplate.json file should be located in
<TemplateRoot>/<Partition>/Package/.

.PARAMETER Sequence
The sequence number for workspace naming, matching the workspace created by
Provision-Workspace.ps1 (e.g., '01', '02').

.PARAMETER Location
The Azure region where the workspace is located (e.g., 'eastus', 'westus2').
Can be set as default in settings.psd1 to avoid typing on every invocation.

.PARAMETER ResourceGroup
Optional name of an existing resource group to use. If not specified, the resource
group name will be generated using the naming convention: sentinel-rg-{username}-{partition}-{sequence}

.PARAMETER WorkspaceName
Optional name of an existing workspace to use. If not specified, the workspace
name will be generated using the naming convention: sentinel-{username}-{partition}-{sequence}

.EXAMPLE
.\Deploy-Solution.ps1 -Partition dev -Sequence 01 -Location eastus
Deploys the solution from the default location (C:\GitHub\Azure-Sentinel\Solutions\dev\Package\mainTemplate.json)
to the dev-01 workspace in East US.

.EXAMPLE
.\Deploy-Solution.ps1 -TemplateRoot C:\Templates -Partition dev -Sequence 01 -Location eastus
Deploys the solution from C:\Templates\dev\Package\mainTemplate.json to the dev-01 workspace in East US.

.EXAMPLE
.\Deploy-Solution.ps1 -TemplateRoot .\solutions -Partition test -Sequence 02 -Location westus2
Deploys the solution from .\solutions\test\Package\mainTemplate.json to the test-02 workspace in West US 2.

.EXAMPLE
.\Deploy-Solution.ps1 -Partition prod -Sequence 01 -ResourceGroup my-existing-rg -Location eastus
Deploys the solution to a specific resource group instead of using the generated name.

.EXAMPLE
.\Deploy-Solution.ps1 -Partition prod -Sequence 01 -ResourceGroup my-rg -WorkspaceName my-workspace -Location eastus
Deploys the solution to a specific resource group and workspace instead of using generated names.

.NOTES
Requires Azure CLI to be installed and authenticated (az login).
The target resource group and workspace must already exist (created by Provision-Workspace.ps1).
Solution template (mainTemplate.json) must exist in the ./<Partition>/ directory.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]
    $TemplateRoot = "C:\GitHub\Azure-Sentinel\Solutions",

    [Parameter(Mandatory=$true)]
    [string]
    $Partition,

    [Parameter(Mandatory=$true)]
    [string]
    $Sequence,

    [Parameter(Mandatory=$false)]
    [string]
    $Location,

    [Parameter(Mandatory=$false)]
    [string]
    $ResourceGroup,

    [Parameter(Mandatory=$false)]
    [string]
    $WorkspaceName
)

# Load settings from settings.psd1 if it exists
$settingsPath = "$PSScriptRoot\settings.psd1"
$defaultLocation = $null
$defaultTemplateRoot = $null

if (Test-Path $settingsPath) {
    $settings = Import-PowerShellDataFile -Path $settingsPath
    if ($settings.Location) {
        $defaultLocation = $settings.Location
    }
    if ($settings.TemplateRoot) {
        $defaultTemplateRoot = $settings.TemplateRoot
    }
}

# Apply defaults if parameters not provided
if (-not $Location) {
    if ($defaultLocation) {
        $Location = $defaultLocation
        Write-Host "Using default location from settings: $Location" -ForegroundColor Cyan
    }
    else {
        throw "Location parameter is required. Either provide -Location or create settings.psd1 with default Location. See settings.example.psd1 for template."
    }
}

if (-not $PSBoundParameters.ContainsKey('TemplateRoot') -and $defaultTemplateRoot) {
    $TemplateRoot = $defaultTemplateRoot
    Write-Host "Using template root from settings: $TemplateRoot" -ForegroundColor Cyan
}

$ErrorActionPreference = "Stop"

try {
    # Sanitize partition name for Azure resource naming (replace spaces with hyphens)
    $PartitionSanitized = $Partition -replace '\s+', '-'
    
    $Suffix = "$env:USERNAME-$PartitionSanitized-$Sequence"
    
    # Use provided resource group or generate name
    if (-not $ResourceGroup) {
        $ResourceGroup = "sentinel-rg-$Suffix"
    }
    
    # Use provided workspace name or generate name
    if (-not $WorkspaceName) {
        $WorkspaceName = "sentinel-$Suffix"
    }
    
    # Resolve template root to absolute path
    $ResolvedTemplateRoot = Resolve-Path $TemplateRoot -ErrorAction Stop
    $TemplatePath = Join-Path $ResolvedTemplateRoot "$Partition\Package\mainTemplate.json"

    # Verify solution template exists
    if (-not (Test-Path $TemplatePath)) {
        throw "Solution template not found: $TemplatePath"
    }

    Write-Host "Checking Azure Subscription..." -ForegroundColor Cyan
    $account = az account show 2>&1 | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to get Azure account information. Please run 'az login' first."
    }

    Write-Host "OK TN=$($account.homeTenantId) SU=$($account.id) $($account.name)" -ForegroundColor Green
    Write-Host ""

    Write-Host "Retrieving template commit information..." -ForegroundColor Cyan
    Push-Location $ResolvedTemplateRoot
    try {
        $gitLog = git log --pretty=format:"%h %ad %s" --date=short -n 1 2>&1
        if ($LASTEXITCODE -eq 0) {
            $commitInfo = $gitLog
            Write-Host "OK Commit: $commitInfo" -ForegroundColor Green
        }
        else {
            $commitInfo = "Not available (not a git repository)"
            Write-Host "WARNING $commitInfo" -ForegroundColor Yellow
        }
    }
    finally {
        Pop-Location
    }
    Write-Host ""

    Write-Host "Deploying solution to Workspace $WorkspaceName in Resource Group $ResourceGroup..." -ForegroundColor Cyan
    $deploymentName = "Deploy-$(Get-Random)"
    az deployment group create `
        --name $deploymentName `
        --resource-group $ResourceGroup `
        --template-file $TemplatePath `
        --parameter workspace-location=$Location `
        --parameter workspace=$WorkspaceName 2>&1 | Out-Null
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to deploy solution with exit code $LASTEXITCODE"
    }

    Write-Host "OK Solution deployed successfully" -ForegroundColor Green
    Write-Host ""

    Write-Host "Deployment Summary:" -ForegroundColor Cyan
    Write-Host "  Tenant:              $($account.homeTenantId)"
    Write-Host "  Subscription:        $($account.id) - $($account.name)"
    Write-Host "  Resource Group:      $ResourceGroup"
    Write-Host "  Workspace:           $WorkspaceName"
    Write-Host "  Location:            $Location"
    Write-Host "  Template Root:       $ResolvedTemplateRoot"
    Write-Host "  Template:            $TemplatePath"
    Write-Host "  Commit:              $commitInfo"
}
catch {
    Write-Error "Failed to deploy solution: $_"
    Write-Error $_.ScriptStackTrace
    exit 1
}
