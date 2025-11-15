# Asset Template Demo - Salesforce Project

A comprehensive Salesforce solution for managing asset templates and generating multiple assets from templates. This project includes custom objects, Lightning Web Components, Apex classes, flows, and more.

## Features

- **Asset Template Management**: Create and manage reusable asset templates
- **Bulk Asset Generation**: Generate multiple assets from a single template with automated naming
- **Maintenance Tracking**: Track maintenance schedules, intervals, and status for assets
- **Asset Hierarchy**: Support for parent-child asset relationships and versioning
- **Financial Tracking**: Monitor purchase costs, current values, warranties, and GL accounts
- **Technical Specifications**: Store firmware versions, IP addresses, MAC addresses, and configuration notes

## Project Components

- **Custom Objects**: AssetTemplate__c, Asset (extended)
- **Apex Classes**: AssetTemplateService, AssetTemplateTriggerHelper, and test classes
- **Lightning Web Components**: assetTemplateGenerator
- **Aura Components**: AssetTemplateGeneratorApp
- **Flows**: Asset_Maintenance_Status_Update
- **Triggers**: AssetTemplateTrigger
- **Layouts**: Custom layouts for Asset and AssetTemplate objects
- **Validation Rules**: Data quality rules for assets

## Prerequisites

Before deploying this project, ensure you have:

1. **Salesforce CLI** installed
   ```bash
   # Install Salesforce CLI (if not already installed)
   npm install -g @salesforce/cli
   
   # Verify installation
   sf --version
   ```

2. **Git** installed
   ```bash
   git --version
   ```

3. **A Salesforce Org** (Production, Sandbox, or Developer Edition)

## Deployment Instructions

### Step 1: Clone the Repository

```bash
git clone <repository-url>
cd asset-template-demo
```

### Step 2: Authenticate to Your Salesforce Org

Choose one of the following authentication methods:

**Option A: Web Login (Recommended)**
```bash
sf org login web --alias myorg
```

**Option B: Using Auth URL**
```bash
sf org login sfdx-url --sfdx-url-file path/to/authfile.txt --alias myorg
```

**Option C: Using Username/Password (for CI/CD)**
```bash
sf org login user --username your-username@example.com --alias myorg
```

### Step 3: Deploy All Metadata

Deploy all components to your org:

```bash
sf project deploy start --source-dir force-app
```

**Alternative: Deploy with validation only (dry run)**
```bash
sf project deploy start --source-dir force-app --dry-run
```

### Step 4: Verify Deployment

Check deployment status:
```bash
sf project deploy report
```

List deployed components:
```bash
sf project deploy report --verbose
```

### Step 5: Assign Permissions (Optional)

If you need to assign permissions to users:

```bash
# Assign permission set (if you have one)
sf org assign permset --name YourPermissionSetName --target-org myorg

# Or update user permissions through Setup UI
```

### Step 6: Run Tests (Optional)

Run Apex tests to verify functionality:

```bash
# Run all tests
sf apex run test --test-level RunLocalTests --result-format human --code-coverage

# Run specific test class
sf apex run test --tests AssetTemplateServiceTest --result-format human --code-coverage
```

## Post-Deployment Steps

1. **Create Asset Templates**
   - Navigate to the Asset Templates tab
   - Create templates for different asset types (e.g., Vehicles, Equipment, IT Assets)

2. **Configure Flows**
   - Activate the "Asset_Maintenance_Status_Update" flow if needed
   - Customize flow logic based on your requirements

3. **Add Lightning Components to Pages**
   - Add the "Asset Template Generator" LWC to relevant Lightning pages
   - Configure component properties as needed

4. **Set Up Validation Rules**
   - Review and activate validation rules for your business requirements

## Development Workflow

### Pull Changes from Org

```bash
sf project retrieve start --source-dir force-app
```

### Deploy Specific Components

```bash
# Deploy specific metadata type
sf project deploy start --metadata ApexClass:AssetTemplateService

# Deploy specific directory
sf project deploy start --source-dir force-app/main/default/classes
```

### Create a Scratch Org (for development)

```bash
# Create scratch org
sf org create scratch --definition-file config/project-scratch-def.json --alias scratch-org --duration-days 30

# Push source to scratch org
sf project deploy start --source-dir force-app --target-org scratch-org

# Open scratch org
sf org open --target-org scratch-org
```

## Troubleshooting

### Common Issues

**Issue: Field conflicts during deployment**
- Some fields may already exist in your org with different types
- Solution: Remove conflicting field metadata files or manually update fields in the org

**Issue: LWC property errors**
- Ensure the component's @api properties match the metadata configuration
- Solution: Check assetTemplateGenerator.js for property definitions

**Issue: Layout references missing quick actions**
- Quick actions referenced in layouts may not exist
- Solution: Remove quick action references from layouts or create the missing quick actions

### View Deployment Logs

```bash
# View recent deployment
sf project deploy report --job-id <deployment-id>

# View deployment with details
sf project deploy report --job-id <deployment-id> --verbose
```

## Project Structure

```
asset-template-demo/
├── force-app/
│   └── main/
│       └── default/
│           ├── aura/                    # Aura components
│           ├── classes/                 # Apex classes
│           ├── flows/                   # Flows
│           ├── layouts/                 # Page layouts
│           ├── lwc/                     # Lightning Web Components
│           ├── objects/                 # Custom objects and fields
│           ├── profiles/                # Profiles
│           ├── tabs/                    # Custom tabs
│           └── triggers/                # Apex triggers
├── sfdx-project.json                    # Project configuration
└── README.md                            # This file
```

## Additional Resources

- [Salesforce Extensions Documentation](https://developer.salesforce.com/tools/vscode/)
- [Salesforce CLI Setup Guide](https://developer.salesforce.com/docs/atlas.en-us.sfdx_setup.meta/sfdx_setup/sfdx_setup_intro.htm)
- [Salesforce DX Developer Guide](https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/sfdx_dev_intro.htm)
- [Salesforce CLI Command Reference](https://developer.salesforce.com/docs/atlas.en-us.sfdx_cli_reference.meta/sfdx_cli_reference/cli_reference.htm)

## Support

For issues or questions, please create an issue in the repository or contact your Salesforce administrator.
