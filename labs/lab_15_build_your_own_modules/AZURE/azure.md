# LAB-15-Azure: Creating and Using Local Modules

## Overview
In this lab, you will create your own local Terraform modules and use them to build Azure resources. You'll create two modules - one for Azure Resource Groups and one for Azure Role Definitions - and then call these modules from a parent configuration. This lab teaches you how to build reusable modules, pass variables between modules, and organize your Terraform code efficiently. All resources created in this lab are part of the Azure free tier or incur minimal costs.

[![Lab 15](https://github.com/btkrausen/terraform-testing/actions/workflows/azure_lab_validation.yml/badge.svg?branch=main)](https://github.com/btkrausen/terraform-testing/actions/workflows/azure_lab_validation.yml)

**Preview Mode**: Use `Cmd/Ctrl + Shift + V` in VSCode to see a nicely formatted version of this lab!

## Prerequisites
- Azure free tier account
- Azure CLI installed and configured
- Basic understanding of Terraform and Azure concepts

Note: Azure credentials are required for this lab.

## How to Use This Hands-On Lab

1. **Create a Codespace** from this repo (click the button below).  
2. Once the Codespace is running, open the integrated terminal.
3. Follow the instructions in each **lab** to complete the exercises.

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/btkrausen/terraform-codespaces)

## Estimated Time
40 minutes

## Lab Steps

### 1. Configure Azure Credentials

Set up your Azure CLI credentials:

```bash
az login
```

If you have multiple subscriptions, select the one you want to use:

```bash
az account set --subscription "Your Subscription Name or ID"
```

### 2. Create the Directory Structure

Create the following directory structure for your project:

```bash
mkdir -p modules/resource_group
mkdir -p modules/role_definition
```

Alternatively, you can create these directories and files using the VSCode UI if you prefer:
- Right-click in the Explorer panel and select "New Folder" to create the "modules" directory
- Right-click on "modules" and create the "resource_group" and "role_definition" subdirectories
- Right-click in the main directory and select "New File" to create each of the .tf files

### 3. Create the Providers File

Add the following content to `providers.tf`:

```hcl
terraform {
  required_version = ">= 1.12.2"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0.0"
    }
  }
}

provider "azurerm" {
  features {}
}
```

### 4. Create the Variables File

Add the following content to `variables.tf`:

```hcl
variable "location" {
  description = "Azure region to deploy resources"
  type        = string
  default     = "East US"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}
```

### 5. Create the Resource Group Module

Create the following files in the `modules/resource_group` directory:

#### a. Create `modules/resource_group/variables.tf`:

```hcl
variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "location" {
  description = "Azure region for the resource group"
  type        = string
}

variable "name_prefix" {
  description = "Prefix for the resource group name"
  type        = string
}

variable "tags" {
  description = "Tags to apply to the resource group"
  type        = map(string)
  default     = {}
}
```

#### b. Create `modules/resource_group/main.tf`:

```hcl
resource "azurerm_resource_group" "this" {
  name     = "${var.environment}-${var.name_prefix}-rg"
  location = var.location

  tags = merge({
    Environment = var.environment
    ManagedBy   = "Terraform"
  }, var.tags)
}
```

#### c. Create `modules/resource_group/outputs.tf`:

```hcl
output "resource_group_id" {
  description = "ID of the resource group"
  value       = azurerm_resource_group.this.id
}

output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.this.name
}

output "resource_group_location" {
  description = "Location of the resource group"
  value       = azurerm_resource_group.this.location
}
```

### 6. Create the Role Definition Module

Create the following files in the `modules/role_definition` directory:

#### a. Create `modules/role_definition/variables.tf`:

```hcl
variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "role_name" {
  description = "Name of the custom role"
  type        = string
}

variable "scope" {
  description = "The scope at which the Role Definition applies to"
  type        = string
}

variable "permissions" {
  description = "List of permissions that are granted by the role"
  type = object({
    actions        = list(string)
    data_actions   = list(string)
    not_actions    = list(string)
    not_data_actions = list(string)
  })
  default = {
    actions        = []
    data_actions   = []
    not_actions    = []
    not_data_actions = []
  }
}

variable "description" {
  description = "Description of the role"
  type        = string
  default     = ""
}
```

#### b. Create `modules/role_definition/main.tf`:

```hcl
resource "azurerm_role_definition" "this" {
  name        = "${var.environment}-${var.role_name}"
  scope       = var.scope
  description = var.description != "" ? var.description : "Custom role for ${var.role_name}"

  permissions {
    actions        = var.permissions.actions
    data_actions   = var.permissions.data_actions
    not_actions    = var.permissions.not_actions
    not_data_actions = var.permissions.not_data_actions
  }

  assignable_scopes = [
    var.scope
  ]
}
```

#### c. Create `modules/role_definition/outputs.tf`:

```hcl
output "role_definition_id" {
  description = "ID of the role definition"
  value       = azurerm_role_definition.this.role_definition_id
}

output "role_definition_name" {
  description = "Name of the role definition"
  value       = azurerm_role_definition.this.name
}

output "role_definition_scope" {
  description = "Scope of the role definition"
  value       = azurerm_role_definition.this.scope
}
```

### 7. Create the Main Configuration

Add the following content to `main.tf` to use your local modules:

```hcl
# Generate a random suffix for resource uniqueness
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# Create Resource Groups using the resource_group module
module "app_resource_group" {
  source      = "./modules/resource_group"
  environment = var.environment
  location    = var.location
  name_prefix = "app"
  
  tags = {
    Application = "WebApp"
    Purpose     = "Application Resources"
  }
}

module "monitoring_resource_group" {
  source      = "./modules/resource_group"
  environment = var.environment
  location    = var.location
  name_prefix = "monitoring"
  
  tags = {
    Application = "Monitoring"
    Purpose     = "Monitoring Resources"
  }
}

# Create custom roles using the role_definition module
module "storage_reader_role" {
  source      = "./modules/role_definition"
  environment = var.environment
  role_name   = "storage-reader"
  scope       = module.app_resource_group.resource_group_id
  description = "Custom role for read-only access to storage accounts"
  
  permissions = {
    actions = [
      "Microsoft.Storage/storageAccounts/read",
      "Microsoft.Storage/storageAccounts/blobServices/containers/read"
    ]
    data_actions     = []
    not_actions      = []
    not_data_actions = []
  }
}

module "metrics_collector_role" {
  source      = "./modules/role_definition"
  environment = var.environment
  role_name   = "metrics-collector"
  scope       = module.monitoring_resource_group.resource_group_id
  description = "Custom role for collecting metrics from resources"
  
  permissions = {
    actions = [
      "Microsoft.Insights/metrics/read",
      "Microsoft.Insights/metricDefinitions/read",
      "Microsoft.Insights/diagnosticSettings/read"
    ]
    data_actions   = []
    not_actions    = []
    not_data_actions = []
  }
}
```

### 8. Create the Outputs File

Add the following content to `outputs.tf`:

```hcl
output "resource_group_ids" {
  description = "IDs of the created resource groups"
  value = {
    app        = module.app_resource_group.resource_group_id,
    monitoring = module.monitoring_resource_group.resource_group_id
  }
}

output "resource_group_names" {
  description = "Names of the created resource groups"
  value = {
    app        = module.app_resource_group.resource_group_name,
    monitoring = module.monitoring_resource_group.resource_group_name
  }
}

output "role_definition_ids" {
  description = "IDs of the created role definitions"
  value = {
    storage_reader   = module.storage_reader_role.role_definition_id,
    metrics_collector = module.metrics_collector_role.role_definition_id
  }
}

output "role_definition_names" {
  description = "Names of the created role definitions"
  value = {
    storage_reader   = module.storage_reader_role.role_definition_name,
    metrics_collector = module.metrics_collector_role.role_definition_name
  }
}
```

### 9. Initialize and Apply

Initialize and apply the configuration:

```bash
terraform init
terraform plan
terraform apply
```

Watch how Terraform:
- Processes each local module
- Creates the resource groups using the resource group module
- Creates the custom roles using the role definition module
- Sets up the proper scopes and permissions

### 10. Clean Up

Remove all created resources:

```bash
terraform destroy
```

## Understanding Local Modules in Azure

Let's examine the key aspects of creating and using local modules with Azure:

### Module Structure
A well-structured Azure module typically contains:
- `main.tf` - The main resource definitions
- `variables.tf` - Input variable definitions
- `outputs.tf` - Output definitions
- Potentially other .tf files for specific resource types

### Module Source
For local modules, the source is a relative path:
```
source = "./modules/resource_group"
```

### Module Inputs
Modules receive input through variables:
```
module "app_resource_group" {
  source      = "./modules/resource_group"
  environment = var.environment
  ...
}
```

### Module Outputs
Modules provide outputs that can be referenced:
```
module.app_resource_group.resource_group_id
```

### Module Reuse
The same module can be used multiple times with different parameters:
```
module "app_resource_group" { ... }
module "monitoring_resource_group" { ... }
```

## Benefits of Using Local Modules in Azure

1. **Consistency**: Enforce standardized Azure resource configurations
2. **Reusability**: Use the same module for multiple resources (e.g., multiple resource groups)
3. **Maintainability**: Update resource configurations in one place
4. **Organization**: Group related resources together
5. **Validation**: Add validation rules to ensure proper parameter values
6. **Documentation**: Document how Azure resources should be configured

## Additional Exercises

1. Create a module for Azure App Service and use it to deploy a simple web app
2. Add conditional resource creation to the storage account module based on a boolean flag
3. Create a networking module that includes a virtual network and subnets
4. Add data sources to retrieve existing Azure resources and pass them to your modules
5. Implement dynamic blocks in your modules to handle variable numbers of configurations

## Tips for Working with Azure Modules

1. **Naming Conventions**: Follow a consistent naming convention for Azure resources
2. **Resource Scopes**: Understand how Azure resource scopes work (subscription, resource group, etc.)
3. **Dependencies**: Use `depends_on` for resources that have dependencies not captured by references
4. **Provider Configuration**: Pass provider configurations to modules if using multiple providers
5. **Secrets Handling**: Use output sensitivity for secrets like access keys