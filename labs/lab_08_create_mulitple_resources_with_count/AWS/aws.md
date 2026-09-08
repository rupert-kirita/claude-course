# LAB-08-AWS: Creating Multiple Resources with the Count Meta-Argument

## Overview
In this lab, you will learn how to use Terraform's `count` meta-argument to create multiple similar resources efficiently. You'll start with a configuration that creates individual resources and refactor it to create multiple resources using count. The lab uses AWS free-tier resources to ensure no costs are incurred.

[![Lab 08](https://github.com/btkrausen/terraform-testing/actions/workflows/aws_lab_validation.yml/badge.svg?branch=main)](https://github.com/btkrausen/terraform-testing/actions/workflows/aws_lab_validation.yml)

**Preview Mode**: Use `Cmd/Ctrl + Shift + V` in VSCode to see a nicely formatted version of this lab!

## Prerequisites
- Terraform installed
- AWS free tier account
- Basic understanding of Terraform and AWS concepts

Note: AWS credentials are required for this lab.

## How to Use This Hands-On Lab

1. **Create a Codespace** from this repo (click the button below).  
2. Once the Codespace is running, open the integrated terminal.
3. Follow the instructions in each **lab** to complete the exercises.

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/btkrausen/terraform-codespaces)

## Estimated Time
40 minutes

## Existing Configuration Files

The lab directory contains the following files with repetitive resource creation that we'll refactor using count:

 - `main.tf`
 - `variables.tf`
 - `providers.tf`

Examine these files and notice:
- Individual subnet resources with similar configuration
- Multiple security groups with similar structure
- Repetitive code that could be simplified

## Lab Steps

### 1. Configure AWS Credentials

Set up your AWS credentials as environment variables:

```bash
export AWS_ACCESS_KEY_ID="your_access_key"
export AWS_SECRET_ACCESS_KEY="your_secret_key"
```

### 2. Update Variables for Count

Modify the `variables.tf` files and add the following variables that will work with count:

```hcl
variable "subnet_count" {
  description = "Number of subnets to create"
  type        = number
  default     = 3
}

variable "availability_zones" {
  description = "Availability zones for subnets"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "subnet_cidr_blocks" {
  description = "CIDR blocks for subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "security_groups" {
  description = "Security group configurations"
  type = list(object({
    name         = string
    description  = string
    ingress_port = number
  }))
  default = [
    {
      name         = "web"
      description  = "Allow web traffic"
      ingress_port = 80
    },
    {
      name         = "app"
      description  = "Allow application traffic"
      ingress_port = 8080
    },
    {
      name         = "db"
      description  = "Allow database traffic"
      ingress_port = 3306
    }
  ]
}
```

### 3. Refactor Subnets Using Count

Replace the individual subnet resources with a single count-based resource in `main.tf`:

Delete the resource blocks for `subnet_1`, `subnet_2`, and `subnet_3` and replace them with the following resource block:

```hcl
# Refactored Subnet Resources using count
resource "aws_subnet" "subnet" {
  count             = var.subnet_count
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.subnet_cidr_blocks[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "subnet-${count.index + 1}"
  }
}
```

### 4. Apply and Test Subnet Count

Initialize and apply the configuration:

```bash
terraform init
terraform plan
terraform apply
```

Verify that three subnets are created with the correct CIDR blocks and availability zones.

### 5. Adjust Subnet Count

Modify the `subnet_count` variable bycreating a `terraform.tfvars` file to test different subnet counts:

```hcl
subnet_count = 2
```

Apply the changes and observe the results:

```bash
terraform plan
terraform apply
```

Notice how Terraform plans to destroy one subnet, maintaining only the number specified in the count.

### 6. Refactor Security Groups Using Count

Next, let's replace the individual security group resources with a count-based approach:

Delete the resource blocks for `aws_security_group.web`, `aws_security_group.app`, and `aws_security_group.db`

Run a `terraform apply` to delete the security groups since we already created them:

```bash
terraform apply -auto-approve
```

Now, replace those deleted security groups with the following resource block:

```hcl
# Refactored Security Groups using count
resource "aws_security_group" "sg" {
  count       = 3  # Creating 3 security groups
  name        = "${var.security_groups[count.index].name}-sg"
  description = var.security_groups[count.index].description
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = var.security_groups[count.index].ingress_port
    to_port     = var.security_groups[count.index].ingress_port
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]  # Using the same CIDR for simplicity
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # -1 means all protocols
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.security_groups[count.index].name}-sg"
  }
}
```

### 7. Create Outputs Using Count

Create an `outputs.tf` file to demonstrate how to reference count-based resources:

```hcl
output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}

output "subnet_ids" {
  description = "The IDs of the subnets"
  value       = aws_subnet.subnet[*].id
}

output "subnet_cidr_blocks" {
  description = "The CIDR blocks of the subnets"
  value       = aws_subnet.subnet[*].cidr_block
}

output "security_group_ids" {
  description = "The IDs of the security groups"
  value       = aws_security_group.sg[*].id
}
```

### 8. Apply Final Configuration

Apply the complete configuration:

```bash
terraform plan
terraform apply
```

### 9. Experiment with Count Values

Let's update our configuration to create different numbers of route tables based on a simple count:

Add this to `variables.tf`:
```hcl
variable "route_table_count" {
  description = "Number of route tables to create"
  type        = number
  default     = 2
}
```

Add these route tables to `main.tf`:

```hcl
# Create multiple route tables
resource "aws_route_table" "example" {
  count  = var.route_table_count
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "route-table-${count.index + 1}"
  }
}
```

Add an additional output block to the `outputs.tf` file:

```hcl
output "route_table_ids" {
  description = "The IDs of the route tables"
  value       = aws_route_table.example[*].id
}
```

Apply the configuration with different route table counts:

```bash
# Set route_table_count to 1
terraform apply -var="route_table_count=1"

# Set route_table_count to 3
terraform apply -var="route_table_count=3"
```

Notice how Terraform creates only the number of `aws_route_tables` based on the variable value. Additionally, notice how the output is also dynamic and outputs the same number of route tables.

### 10. Clean Up

Remove all created resources:

```bash
terraform destroy
```

## Understanding Count

Let's examine how count improves your Terraform configurations:

### Basic Count Usage
- `count = N` creates N instances of a resource
- `count.index` provides the current index (0 to N-1)
- Each resource instance gets a unique index

### Resource References
- Individual resource: `aws_subnet.subnet[0]`
- All resources: `aws_subnet.subnet[*]`
- Specific attribute of all resources: `aws_subnet.subnet[*].id`

### Count with Variables
- Using list variables with count.index
- Dynamically determining count with `length()`
- Conditional creation with `count = condition ? 1 : 0`

### Limitations
- Resources must be identical except for elements that use count.index
- Changing the count can cause resource recreation
- Removing an element from the middle of a list can affect multiple resources

## Additional Exercises

1. Create multiple S3 buckets using count
2. Create multiple Network ACLs with count
3. Try creating a different number of subnets in each availability zone
4. Add associations between your route tables and subnets

## Common Issues and Solutions

1. **Index Out of Range**
   - Ensure list variables have at least as many elements as the count value
   - Be careful when referencing list elements with count.index

2. **Resource Recreation**
   - Be cautious when changing count on existing infrastructure
   - Adding or removing elements can affect resource IDs

3. **Resource References**
   - Always use the [index] or [*] notation when referencing count resources
   - Remember that the index starts at 0, not 1