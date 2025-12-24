# Implementation Plan: Local Settings with .psd1

## Overview
Enable users to set a default `-Location` value via a local `settings.psd1` file, eliminating the need to type `-Location` on every script invocation. The `-Sequence` parameter will remain **mandatory** in all cases.

## Design Principles
- ✅ **Backward Compatible** - Scripts work without settings file
- ✅ **Command Line Override** - CLI arguments always take precedence
- ✅ **Sequence Always Required** - Users must explicitly provide `-Sequence`
- ✅ **Git-Friendly** - Settings file is local-only (gitignored)
- ✅ **User-Friendly** - Provide example template for easy setup

## Files to Modify

### 1. [`Provision-Workspace.ps1`](../Provision-Workspace.ps1)
**Current State:**
- `-Location` is mandatory parameter

**Changes:**
- Change `-Location` parameter to optional with `Mandatory=$false`
- Add settings loading logic after parameters
- Apply default from settings if `-Location` not provided
- Throw clear error if no location available

### 2. [`Deploy-Solution.ps1`](../Deploy-Solution.ps1)
**Current State:**
- `-Location` is mandatory parameter

**Changes:**
- Same pattern as Provision-Workspace.ps1
- Ensure consistency in settings loading

### 3. [`Deploy-Complete.ps1`](../Deploy-Complete.ps1)
**Current State:**
- `-Location` is mandatory parameter

**Changes:**
- Same pattern as other scripts
- Pass location to child scripts when calling them

## Files to Create

### 1. `settings.example.psd1` (Template)
Create example settings file that users can copy:

```powershell
@{
    # Default Azure region for resource deployments
    # Uncomment and set your preferred location, then save as 'settings.psd1'
    # Location = "eastus"
    
    # Common Azure regions:
    # Location = "eastus"        # East US
    # Location = "eastus2"       # East US 2
    # Location = "westus2"       # West US 2
    # Location = "centralus"     # Central US
    # Location = "westeurope"    # West Europe
    # Location = "northeurope"   # North Europe
    
    # Optional: Set default template root if different from default
    # TemplateRoot = "C:\GitHub\Azure-Sentinel\Solutions"
}
```

### 2. Update `.gitignore`
Add entry to ignore local settings:
```
settings.psd1
```

### 3. Update `README.md`
Add section documenting the settings file feature.

## Implementation Pattern

### Settings Loading Logic (Consistent Across All Scripts)

```powershell
# After parameter block, before $ErrorActionPreference
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

# Apply defaults only if parameters not provided
if (-not $Location) {
    if ($defaultLocation) {
        $Location = $defaultLocation
        Write-Host "Using default location: $Location" -ForegroundColor Cyan
    }
    else {
        throw "Location parameter is required. Either provide -Location or create settings.psd1 with default Location. See settings.example.psd1 for template."
    }
}

# For Deploy-Solution.ps1 and Deploy-Complete.ps1 only
if (-not $PSBoundParameters.ContainsKey('TemplateRoot') -and $defaultTemplateRoot) {
    $TemplateRoot = $defaultTemplateRoot
    Write-Host "Using template root from settings: $TemplateRoot" -ForegroundColor Cyan
}
```

## Parameter Updates

### Before (Current):
```powershell
[Parameter(Mandatory=$true)]
[string]
$Location
```

### After (New):
```powershell
[Parameter(Mandatory=$false)]
[string]
$Location
```

**Note:** `-Sequence` remains unchanged:
```powershell
[Parameter(Mandatory=$true)]  # ALWAYS mandatory
[string]
$Sequence
```

## User Workflow

### Initial Setup (One-Time)
```powershell
# 1. Copy example to settings.psd1
Copy-Item settings.example.psd1 settings.psd1

# 2. Edit settings.psd1 and uncomment/set Location
# Location = "eastus"

# 3. Save file
```

### Daily Usage

**Before (with settings):**
```powershell
.\Provision-Workspace.ps1 -Partition dev -Sequence 01 -Location eastus
```

**After (with settings):**
```powershell
.\Provision-Workspace.ps1 -Partition dev -Sequence 01
# Location loaded from settings.psd1
```

**Override when needed:**
```powershell
.\Provision-Workspace.ps1 -Partition dev -Sequence 01 -Location westus2
# Command line overrides settings file
```

## Error Handling

### Scenario 1: No settings file + No -Location
```
Error: Location parameter is required. Either provide -Location or create settings.psd1 
with default Location. See settings.example.psd1 for template.
```

### Scenario 2: Settings file exists but Location not set
```
Error: Location parameter is required. Either provide -Location or create settings.psd1 
with default Location. See settings.example.psd1 for template.
```

### Scenario 3: Settings file malformed
```
Error: Failed to load settings.psd1: [PowerShell parse error]
```

## Validation Checklist

- [ ] All three scripts modified consistently
- [ ] `-Location` parameter changed to optional
- [ ] Settings loading logic added before main try block
- [ ] Default application logic works correctly
- [ ] Command line override works
- [ ] Error messages are clear and helpful
- [ ] `settings.example.psd1` created with documentation
- [ ] `.gitignore` updated to exclude `settings.psd1`
- [ ] `README.md` updated with setup instructions
- [ ] `-Sequence` remains mandatory in all cases
- [ ] Backward compatible (works without settings file if -Location provided)

## Additional Benefits

1. **TemplateRoot Support** - Can also default `TemplateRoot` for Deploy-Solution.ps1
2. **Extensible** - Easy to add more settings in future (e.g., naming conventions)
3. **PowerShell Native** - Uses built-in cmdlet, no external dependencies
4. **Syntax Validation** - VSCode validates .psd1 syntax automatically

## Testing Scenarios

1. ✅ Script with `-Location` on CLI (no settings file) → Uses CLI value
2. ✅ Script with `-Location` on CLI (settings file exists) → CLI overrides settings
3. ✅ Script without `-Location` (settings file with Location) → Uses settings
4. ✅ Script without `-Location` (no settings file) → Clear error
5. ✅ Script without `-Location` (settings file without Location key) → Clear error
6. ✅ `-Sequence` always required regardless of settings file

## Commit Message

```
feat: add local settings support via settings.psd1

Enable users to set default Location via settings.psd1 file, reducing 
repetitive parameter entry. Command line arguments always override 
settings file. Sequence parameter remains mandatory.

- Change Location parameter to optional in all three scripts
- Add settings loading logic using Import-PowerShellDataFile
- Create settings.example.psd1 template with documentation
- Update .gitignore to exclude settings.psd1
- Update README with setup instructions
- Maintain backward compatibility for users without settings file
```
