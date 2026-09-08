###############################################################################
# variables.tf — input variables + shared locals
###############################################################################

variable "region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "eu-west-1"
}

variable "project_name" {
  description = "Short name used as a prefix for all resource names."
  type        = string
  default     = "demo"
}

variable "environment" {
  description = "Environment name (dev/staging/prod). Used in tags."
  type        = string
  default     = "dev"
}

variable "cluster_name" {
  description = "Name of the EKS cluster."
  type        = string
  default     = "demo-eks"
}

variable "kubernetes_version" {
  description = "Kubernetes control-plane version for EKS."
  type        = string
  default     = "1.31"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "az_count" {
  description = "Number of Availability Zones to span."
  type        = number
  default     = 2
}

variable "node_instance_types" {
  description = "Instance types for the managed node group."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_group_min_size" {
  description = "Minimum number of worker nodes."
  type        = number
  default     = 2
}

variable "node_group_max_size" {
  description = "Maximum number of worker nodes."
  type        = number
  default     = 4
}

variable "node_group_desired_size" {
  description = "Desired number of worker nodes at creation time."
  type        = number
  default     = 2
}

variable "cluster_admin_user_name" {
  description = "Name of the IAM user granted cluster-admin access via EKS Access Entries."
  type        = string
  default     = "omar"
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDRs allowed to reach the public API endpoint. Lock this down in production."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "namespaces" {
  description = "Application namespaces to create in the cluster."
  type        = list(string)
  default     = ["frontend", "backend"]
}

###############################################################################
# Locals
###############################################################################

locals {
  name = "${var.project_name}-${var.environment}"

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
