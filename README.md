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