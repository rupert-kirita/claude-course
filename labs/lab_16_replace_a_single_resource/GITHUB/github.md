# LAB-16-GITHUB: Replacing and Removing Resources in Terraform

## Overview
In this lab, you will learn how to replace and remove resources in Terraform when working with GitHub. You'll practice using the `-replace` flag and removing resources from configuration using GitHub resources.

[![Lab 16](https://github.com/btkrausen/terraform-testing/actions/workflows/github_lab_validation.yml/badge.svg?branch=main)](https://github.com/btkrausen/terraform-testing/actions/workflows/github_lab_validation.yml)

## Prerequisites
- Terraform installed (v1.0.0+)
- GitHub account
- GitHub personal access token with appropriate permissions

## Estimated Time
30 minutes

## Initial Configuration Files

Create the following files in your working directory:

 - `variables.tf`
 - `main.tf`
 - `providers.tf`
 - `outputs.tf`

## Lab Steps

### 1. Configure GitHub Credentials

```bash
export GITHUB_TOKEN="<your_github_token>"
```

### 2. Initialize and Apply
```bash
terraform init
terraform apply -auto-approve
```

### 3. Replace a Resource Using the `-replace` Flag

Let's replace the README file without changing its configuration:

```bash
terraform apply -replace="github_repository_file.readme" -auto-approve
```

Observe in the output how Terraform:
- Re-creates the file with the same content
- Note that with GitHub files, this results in a new commit

### 4. Replace a Resource by Modifying Configuration

Let's update the variables to change the repository's configuration. Create a file called `modified.tfvars`:

```hcl
prefix = "tflab16mod"
repository_description = "Modified repository for Terraform lab"
repository_topics = ["terraform", "lab", "modified", "example"]
```

Apply with the new variables:

```bash
terraform apply -var-file="modified.tfvars" -auto-approve
```

Observe how Terraform:
- Creates a new repository (since the name changes)
- Updates existing properties like description and topics

### 5. Remove a Resource by Deleting it from Configuration

Remove or comment out the branch protection resource from `main.tf`:

```hcl
# Branch Protection
# resource "github_branch_protection" "main" {
#   repository_id = github_repository.example.node_id
#   pattern       = "main"
#   
#   required_pull_request_reviews {
#     dismiss_stale_reviews           = true
#     required_approving_review_count = 1
#   }
# }
```

> Hint: You can quickly toggle single line comments by highlighting the lines and using the `Command` + `/` on Mac or `CTL` + `/` on Windows.

Apply the changes:

```bash
terraform apply -auto-approve
```

Observe that Terraform will remove the branch protection rule because it's no longer part of our configuration (because we commented it out).

### 6. Remove a Resource Using `terraform destroy -target`

Now, let's remove the **development** branch using targeted destroy without changing the configuration:

```bash
terraform destroy -target=github_branch.development -auto-approve
```

Notice that Terraform will destroy the GitHub Branch since we targeted that specific resource on a `terraform destroy` command. Type in `yes` to confirm and destroy the resource.

Verify it's gone:

```bash
terraform state list
```

You should NOT see a `github_branch.development` in the list of managed resources.


Run a normal apply to recreate it - this is because we did NOT remove it from our desired configuration (`main.tf`) and Terraform compared the real-world resources to our desired configuration and, as a result, created the policy definition again.

```bash
terraform apply -auto-approve
```

### 7. Clean Up

When finished, clean up all resources:

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

1. Add a GitHub team resource and provide it access to the repository, then practice replacing and removing it
2. Create a terraform.tfvars file that changes multiple variables at once, then observe which resources get replaced
3. Try adding webhook configurations to the repository and practice replacing them with different settings