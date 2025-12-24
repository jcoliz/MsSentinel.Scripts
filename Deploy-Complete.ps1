<#
.SYNOPSIS
Provisions a Microsoft Sentinel workspace and deploys a solution to it.

.DESCRIPTION
This script orchestrates the complete deployment process by first provisioning
a new Microsoft Sentinel workspace with Log Analytics, then deploying a solution
template to that workspace. It calls Provision-Workspace.ps1 followed by
Deploy-Solution.ps1 in sequence.

.PARAMETER TemplateRoot
The root directory path containing solution template subdirectories. The script
will look for mainTemplate.json in <TemplateRoot>/<Partition>/Package/.
Defaults to C:\GitHub\Azure-Sentinel\Solutions.

.PARAMETER Partition
The partition identifier for resource naming and solution template directory name
(e.g., 'dev', 'test', 'prod'). This is used for workspace naming and to locate
the solution template at <TemplateRoot>/<Partition>/Package/mainTemplate.json.

.PARAMETER Sequence
The sequence number for resource naming, allowing multiple instances (e.g., '01', '02').

.PARAMETER Location
The Azure region where resources will be created (e.g., 'eastus', 'westus2').

.EXAMPLE
.\Deploy-Complete.ps1 -Partition dev -Sequence 01 -Location eastus
Provisions a Sentinel workspace and deploys the dev solution from the default template location.

.EXAMPLE
.\Deploy-Complete.ps1 -TemplateRoot C:\Templates -Partition test -Sequence 02 -Location westus2
Provisions a Sentinel workspace and deploys the test solution from C:\Templates\test\Package\.

.EXAMPLE
.\Deploy-Complete.ps1 -TemplateRoot .\solutions -Partition prod -Sequence 01 -Location eastus
Provisions a Sentinel workspace and deploys the prod solution from a relative path.

.NOTES
Requires Azure CLI to be installed and authenticated (az login).
Calls Provision-Workspace.ps1 and Deploy-Solution.ps1 in sequence.
If provisioning fails, the solution deployment will not be attempted.
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

    [Parameter(Mandatory=$true)]
    [string]
    $Location
)

$ErrorActionPreference = "Stop"

try {
    $ProvisionScript = "$PSScriptRoot\Provision-Workspace.ps1"
    $DeployScript = "$PSScriptRoot\Deploy-Solution.ps1"

    # Verify both scripts exist
    if (-not (Test-Path $ProvisionScript)) {
        throw "Provision script not found: $ProvisionScript"
    }

    if (-not (Test-Path $DeployScript)) {
        throw "Deploy script not found: $DeployScript"
    }

    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Complete Deployment Starting" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    # Step 1: Provision the workspace
    Write-Host "Step 1: Provisioning Workspace..." -ForegroundColor Cyan
    Write-Host ""
    
    & $ProvisionScript -Partition $Partition -Sequence $Sequence -Location $Location
    
    if ($LASTEXITCODE -ne 0) {
        throw "Workspace provisioning failed with exit code $LASTEXITCODE"
    }

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    # Step 2: Deploy the solution
    Write-Host "Step 2: Deploying Solution..." -ForegroundColor Cyan
    Write-Host ""
    
    & $DeployScript -TemplateRoot $TemplateRoot -Partition $Partition -Sequence $Sequence -Location $Location
    
    if ($LASTEXITCODE -ne 0) {
        throw "Solution deployment failed with exit code $LASTEXITCODE"
    }

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "OK Complete Deployment Finished Successfully" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Cyan
}
catch {
    Write-Error "Failed to complete deployment: $_"
    Write-Error $_.ScriptStackTrace
    exit 1
}
