<#
.SYNOPSIS
Provisions a Microsoft Sentinel workspace with Log Analytics in Azure.

.DESCRIPTION
This script creates a new resource group and deploys a complete Microsoft Sentinel
workspace with associated Log Analytics workspace. The resources are named using a
combination of username, partition, and sequence number for uniqueness.

.PARAMETER Partition
The partition identifier for resource naming (e.g., 'dev', 'test', 'prod').

.PARAMETER Sequence
The sequence number for resource naming, allowing multiple instances (e.g., '01', '02').

.PARAMETER Location
The Azure region where resources will be created (e.g., 'eastus', 'westus2').

.EXAMPLE
.\Provision-Workspace.ps1 -Partition dev -Sequence 01 -Location eastus
Provisions a Sentinel workspace in the East US region with dev-01 naming.

.EXAMPLE
.\Provision-Workspace.ps1 -Partition test -Sequence 02 -Location westus2
Provisions a Sentinel workspace in the West US 2 region with test-02 naming.

.NOTES
Requires Azure CLI to be installed and authenticated (az login).
Uses Bicep template from AzDeploy.Bicep/SecurityInsights/sentinel-complete.bicep.
#>

[CmdletBinding()]
param(
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
    $Suffix = "$env:USERNAME-$Partition-$Sequence"
    $ResourceGroup = "sentinel-rg-$Suffix"
    $TemplatePath = "$PSScriptRoot/AzDeploy.Bicep/SecurityInsights/sentinel-complete.bicep"

    # Verify Bicep template exists
    if (-not (Test-Path $TemplatePath)) {
        throw "Bicep template not found: $TemplatePath"
    }

    Write-Host "Checking Azure Subscription..." -ForegroundColor Cyan
    $account = az account show 2>&1 | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to get Azure account information. Please run 'az login' first."
    }

    Write-Host "OK TN=$($account.homeTenantId) SU=$($account.id) $($account.name)" -ForegroundColor Green
    Write-Host ""

    Write-Host "Creating Resource Group $ResourceGroup in $Location..." -ForegroundColor Cyan
    
    $rawOutput = az group create --name $ResourceGroup --location $Location 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        # Check if it's an authorization error
        if ($rawOutput -match "AuthorizationFailed") {
            Write-Host ""
            Write-Host "Authorization Error Details:" -ForegroundColor Red
            Write-Host $rawOutput -ForegroundColor Red
            Write-Host ""
            throw "Authorization failed: You lack permissions to create resource groups. Please ask your administrator to create resource group '$ResourceGroup' or grant you 'Contributor' role on the subscription. See error details above."
        }
        else {
            throw "Failed to create resource group: $rawOutput"
        }
    }
    
    # Parse the JSON output
    try {
        $rg = $rawOutput | ConvertFrom-Json
        Write-Host "OK $($rg.id)" -ForegroundColor Green
    }
    catch {
        throw "Failed to parse Azure CLI output as JSON: $rawOutput"
    }
    Write-Host ""

    Write-Host "Creating Sentinel Workspace in $ResourceGroup..." -ForegroundColor Cyan
    $deploymentName = "Deploy-$(Get-Random)"
    
    # Capture raw output
    $rawDeployOutput = az deployment group create `
        --name $deploymentName `
        --resource-group $ResourceGroup `
        --template-file $TemplatePath `
        --parameter suffix=$Suffix 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "Deployment Failed - Raw Output:" -ForegroundColor Red
        Write-Host $rawDeployOutput -ForegroundColor Red
        Write-Host ""
        throw "Failed to deploy Sentinel workspace with exit code $LASTEXITCODE"
    }
    
    # Convert output to string (handles ErrorRecord objects from 2>&1)
    $outputString = $rawDeployOutput | Out-String
    
    # Extract JSON from output (strip any WARNING or other prefix messages)
    # Find the first '{' which marks the start of JSON
    $jsonStart = $outputString.IndexOf('{')
    if ($jsonStart -lt 0) {
        throw "No JSON found in deployment output"
    }
    
    $jsonOutput = $outputString.Substring($jsonStart)
    
    # Parse the JSON
    try {
        $sentinel = $jsonOutput | ConvertFrom-Json
    }
    catch {
        Write-Host ""
        Write-Host "JSON Parse Error - Extracted JSON:" -ForegroundColor Red
        Write-Host $jsonOutput -ForegroundColor Red
        Write-Host ""
        throw "Failed to parse deployment output as JSON: $_"
    }

    $workspaceName = $sentinel.properties.outputs.logAnalyticsName.value
    $workspaceId = $sentinel.properties.outputs.logAnalyticsWorkspaceId.value
    $duration = $sentinel.properties.duration

    Write-Host "OK $workspaceName ID: $workspaceId Duration: $duration" -ForegroundColor Green
    Write-Host ""

    Write-Host "$Partition:" -ForegroundColor Cyan
    Write-Host "  Tenant:              $($account.homeTenantId)"
    Write-Host "  Subscription:        $($account.id) - $($account.name)"
    Write-Host "  Resource Group:      $ResourceGroup in $Location"
    Write-Host "  Log Analytics Name:  $workspaceName"
    Write-Host "  Workspace ID:        $workspaceId"
}
catch {
    Write-Error "Failed to provision workspace: $_"
    Write-Error $_.ScriptStackTrace
    exit 1
}
