<img src="https://github.com/Yashraghuvans/AssetFlow-Pro/blob/main/Snapshots/cover_image.png"/>

# Enterprise Asset Management System Based on CRM

A comprehensive Salesforce solution for managing asset templates and generating multiple assets from templates. This project includes custom objects, Lightning Web Components, Apex classes, flows, and more.

---

## 🚀 Features

- **Asset Template Management**: Create and manage reusable asset templates  
- **Bulk Asset Generation**: Generate multiple assets from a single template with automated naming  
- **Maintenance Tracking**: Track maintenance schedules, intervals, and status for assets  
- **Asset Hierarchy**: Support for parent-child asset relationships and versioning  
- **Financial Tracking**: Monitor purchase costs, current values, warranties, and GL accounts  
- **Technical Specifications**: Store firmware versions, IP addresses, MAC addresses, and configuration notes  

---

## 📸 Demo

Explore the visual tour of the application, including the Dashboard and Asset Management screens:

👉 **[View Application Demo & Snapshots](DEMO.md)**

---

## 📦 Project Components

| Component Type       | Details |
|----------------------|---------|
| **Custom Objects** | `AssetTemplate__c`, `Asset` (extended), `Maintenance__c` |
| **Platform Events** | `Version_Transitioned__e` |
| **Apex Classes** | `AssetTemplateService`, `AssetTemplateTriggerHelper`, `AssetDashboardController`, `AssetVersionController`, `DailyOverdueDigest`, `AssetTriggerHandler`, and associated test classes |
| **Lightning Web Components** | `assetTemplateGenerator`, `assetDashboard`, `assetVersionTransition`, `simpleChart` |
| **Flows** | `Asset_Maintenance_Status_Update` |
| **Triggers** | `AssetTemplateTrigger`, `AssetTrigger` |
| **Quick Actions** | `Asset.Manage_Version`, `Asset.Schedule_Maintenance` |
| **Email Templates** | `Asset_Overdue_Maintenance_Alert` |
| **Static Resources** | `chartjs` |
| **Layouts** | Custom layouts for Asset and `AssetTemplate__c` objects |
| **Validation Rules** | Data quality rules for assets |

---

## 🛠️ Prerequisites

Ensure you have the following installed:

### Salesforce CLI

```bash
# Install Salesforce CLI (if not already installed)
npm install -g @salesforce/cli

# Verify installation
sf --version

```

### Git

```bash
git --version

```

### Salesforce Org

Any of:

* Production
* Sandbox
* Developer Edition

---

## 📥 Deployment Instructions

### Step 1: Clone the Repository

```bash
git clone <repository-url>
cd asset-template-demo

```

### Step 2: Authenticate to Your Salesforce Org

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

```bash
sf project deploy start --source-dir force-app

```

**Dry Run (Validate Only)**

```bash
sf project deploy start --source-dir force-app --dry-run

```

### Step 4: Verify Deployment

```bash
sf project deploy report

```

Or with verbose output:

```bash
sf project deploy report --verbose

```

### Step 5: Assign Permissions (Optional)

```bash
sf org assign permset --name YourPermissionSetName --target-org myorg

```

### Step 6: Run Tests (Optional)

```bash
sf apex run test --test-level RunLocalTests --result-format human --code-coverage

```

*Run specific tests*

```bash
sf apex run test --tests AssetTemplateServiceTest --result-format human --code-coverage

```

---

## 📋 Post-Deployment Steps

1. **Create Asset Templates**
* Navigate to the *Asset Templates* tab
* Create templates for different asset types (e.g., Vehicles, Equipment, IT Assets)


2. **Configure Flows**
* Activate the `Asset_Maintenance_Status_Update` flow
* Customize according to your business processes


3. **Add LWCs to Pages**
* Add components like `Asset Template Generator` and `Asset Management Dashboard` to Lightning record or app pages


4. **Enable Validation Rules**
* Review and activate rules to ensure data integrity



---

## 🧑‍💻 Development Workflow

### Pull Metadata from Org

```bash
sf project retrieve start --source-dir force-app

```

### Deploy Specific Component

```bash
sf project deploy start --metadata ApexClass:AssetTemplateService

```

### Create a Scratch Org

```bash
sf org create scratch --definition-file config/project-scratch-def.json --alias scratch-org --duration-days 30
sf project deploy start --source-dir force-app --target-org scratch-org
sf org open --target-org scratch-org

```

---

## 🐞 Troubleshooting

| Issue | Possible Fix |
| --- | --- |
| Field conflicts | Remove or update conflicting fields |
| LWC property mismatch | Confirm `@api` properties in component JS match metadata |
| Missing quick actions | Create missing quick actions or remove references in layouts |

**View Deployment Logs**

```bash
sf project deploy report --job-id <deployment-id>
sf project deploy report --job-id <deployment-id> --verbose

```

---

## 📂 Project Structure

```
asset-template-demo/
├── force-app/
│   └── main/
│       └── default/
│           ├── classes/             
│           ├── email/               
│           ├── flows/               
│           ├── layouts/             
│           ├── lwc/                 
│           ├── objects/             
│           ├── profiles/            
│           ├── quickActions/        
│           ├── staticresources/     
│           ├── tabs/                
│           └── triggers/            
├── sfdx-project.json                
└── README.md                        

```
