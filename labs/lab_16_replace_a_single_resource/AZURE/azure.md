# LAB-16-Azure: Replacing and Removing Resources in Terraform

## Overview
In this lab, you will learn how to replace and remove resources in Terraform. You'll practice using the `-replace` flag and removing resources from configuration using free Azure resources.

[![Lab 16](https://github.com/btkrausen/terraform-testing/actions/workflows/azure_lab_validation.yml/badge.svg?branch=main)](https://github.com/btkrausen/terraform-testing/actions/workflows/azure_lab_validation.yml)

## Prerequisites
- Terraform installed
- Azure free tier account
- Basic understanding of Terraform and Azure concepts

Note: Azure credentials are required for this lab.

## How to Use This Hands-On Lab

1. **Create a Codespace** from this repo (click the button below).  
2. Once the Codespace is running, open the integrated terminal.
3. Follow the instructions in each **lab** to complete the exercises.

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/[your-username]/terraform-codespaces)

## Estimated Time
30 minutes

## Initial Configuration Files

Check out the following files in your working directory that contain Terrform configurations:

 - `variables.tf`
 - `main.tf`
 - `providers.tf`
 - `outputs.tf`

> Note: Since we're focused on replacing and removing resources, this lab won't require writing a lot of Terraform.

## Lab Steps

### 1. Initialize and Apply
```bash
terraform init
terraform plan
terraform apply -auto-approve
```

> Yes, the Azure provider is slooow. Be patient :)

### 2. Replace a Resource Using the `-replace` Flag

Let's replace the user-assigned identity without changing its configuration:

```bash
terraform apply -replace="azurerm_user_assigned_identity.example" -auto-approve
```

Observe in the output how Terraform:
- Destroys the existing identity
- Creates a new identity with the same configuration

### 3. Replace a Resource by Modifying Configuration

Let's update the variables to change the storage account's configuration. Create a file called `modified.tfvars`:

```hcl
prefix = "tfmod"
storage_account_tag_name = "modified-storage"
environment = "test"
```

Apply the configuration using the new variable values:

```bash
terraform apply -var-file="modified.tfvars" -auto-approve
```

Observe how Terraform plans to replace the storage account due to the name change.

### 4. Remove a Resource by Deleting it from Configuration

Remove or comment out the role assignment resource from `main.tf`:

```hcl
# Role Assignment
# resource "azurerm_role_assignment" "example" {
#   scope                = azurerm_storage_account.example.id
#   role_definition_name = var.role_definition_name
#   principal_id         = azurerm_user_assigned_identity.example.principal_id
# }
```

> Hint: You can quickly toggle single line comments by highlighting the lines and using the `Command` + `/` on Mac or `CTL` + `/` on Windows.

Apply the changes:

```bash
terraform apply -auto-approve
```

Observe that Terraform plans to destroy the role assignment since we "removed" it from our `main.tf` file and it is no longer part of our desired configuration.

### 5. Remove a Resource Using `terraform destroy -target`

Now, let's remove the policy definition using targeted destroy without changing the configuration:

```bash
terraform destroy -target=azurerm_policy_definition.example
```

Notice that Terraform will destroy the policy definition since we targeted that specific resource on a `terraform destroy` command. Type in `yes` to confirm and destroy the resource.

Verify it's gone:

```bash
terraform state list
```

Run a normal apply to recreate it - this is because we did NOT remove it from our desired configuration (`main.tf`) and Terraform compared the real-world resources to our desired configuration and, as a result, created the policy definition again.

```bash
terraform apply -auto-approve
```

### 6. Clean Up

When finished, clean up all resources and remove them from your account:

```bash
terraform destroy -auto-approve
```

## Key Concepts

### Resource Replacement Methods
- **Using `-replace` flag**: Forces resource recreation without configuration changes
- **Changing force-new attributes**: Some attribute changes automatically trigger replacement

### Resource Removal Methods
- **Removing from configuration**: Delete the resource block from your .tf files
- **Using `terraform destroy -target`**: Temporarily removes a resource; it will be recreated on next apply

## Additional Challenge

1. Create a terraform.tfvars file that changes multiple variables at once, then observe which resources get replaced
2. Try using `-replace` with a resource that has dependencies and observe how Terraform handles the dependencies
