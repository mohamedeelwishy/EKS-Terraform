###############################################################################
# outputs.tf
###############################################################################

output "region" {
  description = "AWS region the infrastructure lives in."
  value       = var.region
}

# --- Network -----------------------------------------------------------------

output "vpc_id" {
  description = "ID of the created VPC."
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs (worker nodes, internal load balancers)."
  value       = module.vpc.private_subnets
}

output "public_subnet_ids" {
  description = "Public subnet IDs (internet-facing load balancers, NAT)."
  value       = module.vpc.public_subnets
}

# --- Cluster -----------------------------------------------------------------

output "cluster_name" {
  description = "Name of the EKS cluster."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Kubernetes API server endpoint."
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded CA cert for the cluster."
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS control plane."
  value       = module.eks.cluster_security_group_id
}

output "oidc_provider_arn" {
  description = "ARN of the IAM OIDC provider — use this for IRSA trust policies."
  value       = module.eks.oidc_provider_arn
}

# --- Access ------------------------------------------------------------------

output "cluster_admin_user_arn" {
  description = "ARN of the IAM user granted cluster-admin via EKS Access Entries."
  value       = aws_iam_user.cluster_admin.arn
}

output "configure_kubectl" {
  description = "Command to generate a local kubeconfig for this cluster."
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}

# --- Workload ----------------------------------------------------------------

output "frontend_load_balancer_hostname" {
  description = "Public DNS name of the NLB created by the frontend Service."
  value       = try(kubernetes_service.frontend.status[0].load_balancer[0].ingress[0].hostname, null)
}
