# Microsoft Sentinel Script Helpers

This repo contains scripts which are helpful when working with Microsoft Sentinel workspaces at scale.

## Getting Started

This repository uses [AzDeploy.Bicep](https://github.com/jcoliz/AzDeploy.Bicep) as a submodule. **You must clone with submodules** for the scripts to work correctly.

### Clone with Submodules

**For a new clone:**

```bash
git clone --recurse-submodules https://github.com/jcoliz/MsSentinel.Scripts.git
```

**If you already cloned without submodules:**

```bash
git submodule update --init --recursive
```

### Verify Submodule Setup

After cloning, verify that the `AzDeploy.Bicep` directory contains files (not just an empty directory):

```bash
ls AzDeploy.Bicep
```

You should see subdirectories like `App`, `Compute`, `SecurityInsights`, etc.

## Configuration

### Optional: Local Settings File

To avoid typing the same parameters repeatedly, you can create a local [`settings.psd1`](settings.psd1) file to set default values:

1. **Copy the example file:**
   ```powershell
   Copy-Item settings.example.psd1 settings.psd1
   ```

2. **Edit [`settings.psd1`](settings.psd1) and uncomment/set your preferences:**
   ```powershell
   @{
       # Default Azure region for deployments
       Location = "eastus"
       
       # Optional: Default template root (for Deploy-Solution.ps1)
       # TemplateRoot = "C:\GitHub\Azure-Sentinel\Solutions"
   }
   ```

3. **Save the file** - It's gitignored so it stays local to your machine

**Supported Settings:**
- **`Location`** - Default Azure region (e.g., `"eastus"`, `"westus2"`)
- **`TemplateRoot`** - Default path to solution templates (for [`Deploy-Solution.ps1`](Deploy-Solution.ps1) and [`Deploy-Complete.ps1`](Deploy-Complete.ps1))

**Notes:**
- Command line parameters always override settings file values
- The [`settings.psd1`](settings.psd1) file is optional - scripts work without it if you provide parameters
- The `-Sequence` parameter is always required (no default available)

### Usage Examples

**Without settings file:**
```powershell
.\Provision-Workspace.ps1 -Partition dev -Sequence 01 -Location eastus
```

**With settings file (Location = "eastus"):**
```powershell
.\Provision-Workspace.ps1 -Partition dev -Sequence 01
# Location loaded from settings.psd1 automatically
```

**Override settings file:**
```powershell
.\Provision-Workspace.ps1 -Partition dev -Sequence 01 -Location westus2
# Uses westus2 instead of settings file value
```