
# EKS control plane, managed node group, IAM user + Access Entries

data "aws_caller_identity" "current" {}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

  cluster_name    = var.cluster_name
  cluster_version = var.kubernetes_version

  # API endpoint exposure. Keep public access on so you can reach the cluster
  # from your laptop; restrict the CIDR list in anything beyond a sandbox.
  cluster_endpoint_public_access       = true
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs
  cluster_endpoint_private_access      = true

  # --- OIDC / IRSA 
  # Creates the IAM OIDC identity provider for the cluster so ServiceAccounts
  # can assume IAM roles (IRSA) instead of using node instance profiles.
  enable_irsa = true

  # --- Authentication mode --------------------------------------------------
  # "API" = EKS Access Entries ONLY. The legacy aws-auth ConfigMap is not
  # created or consulted at all. ("API_AND_CONFIG_MAP" would keep both.)
  authentication_mode = "API"

  # Grants the identity running `terraform apply` cluster-admin, so the
  # kubernetes provider in k8s.tf can actually talk to the cluster.
  enable_cluster_creator_admin_permissions = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets # worker nodes live in private subnets

  # --- Core addons ----------------------------------------------------------
  cluster_addons = {
    # vpc-cni must exist before nodes join, hence before_compute.
    vpc-cni = {
      most_recent    = true
      before_compute = true
    }
    kube-proxy = {
      most_recent = true
    }
    coredns = {
      most_recent = true
    }
  }

  eks_managed_node_group_defaults = {
    ami_type       = "AL2023_x86_64_STANDARD"
    disk_size      = 30
    instance_types = var.node_instance_types
  }

  eks_managed_node_groups = {
    default = {
      name = "${local.name}-ng"

      instance_types = var.node_instance_types
      capacity_type  = "ON_DEMAND"

      min_size     = var.node_group_min_size
      max_size     = var.node_group_max_size
      desired_size = var.node_group_desired_size

      # Lets you shell into nodes via SSM without opening SSH / a bastion.
      iam_role_additional_policies = {
        AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      }

      labels = {
        role = "general"
      }
    }
  }

  tags = local.tags
}

###############################################################################
# IAM user "omar"
###############################################################################

resource "aws_iam_user" "cluster_admin" {
  name = var.cluster_admin_user_name
  path = "/"

  tags = merge(local.tags, {
    Purpose = "EKS cluster administrator"
  })
}

# The access entry governs authorization *inside* the cluster, but the user
# still needs eks:DescribeCluster on the AWS side to run
# `aws eks update-kubeconfig`.
resource "aws_iam_policy" "eks_describe" {
  name        = "${local.name}-eks-describe"
  description = "Allows generating a kubeconfig for the ${var.cluster_name} cluster"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
        ]
        Resource = "*"
      }
    ]
  })

  tags = local.tags
}

resource "aws_iam_user_policy_attachment" "cluster_admin_describe" {
  user       = aws_iam_user.cluster_admin.name
  policy_arn = aws_iam_policy.eks_describe.arn
}

###############################################################################
# EKS Access Entries (the modern replacement for the aws-auth ConfigMap)
###############################################################################

# Step 1: register the IAM principal with the cluster.
resource "aws_eks_access_entry" "cluster_admin" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_user.cluster_admin.arn
  type          = "STANDARD" # STANDARD = IAM user/role mapped to a k8s identity

  tags = local.tags
}

# Step 2: attach an AWS-managed access policy to that principal.
# AmazonEKSClusterAdminPolicy == cluster-admin. Swap for
# AmazonEKSAdminPolicy / AmazonEKSEditPolicy / AmazonEKSViewPolicy to narrow it,
# and use access_scope type "namespace" to limit the blast radius.
resource "aws_eks_access_policy_association" "cluster_admin" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_user.cluster_admin.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster" # alternative: type = "namespace", namespaces = ["frontend"]
  }

  # The entry must exist before a policy can be associated with it.
  depends_on = [aws_eks_access_entry.cluster_admin]
}
