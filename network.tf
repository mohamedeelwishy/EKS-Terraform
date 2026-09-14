
 #VPC, subnets, NAT gateway, Kubernetes discovery tags


data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"] # skip Local Zones / Wavelength
  }
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  # /16 split into /24s: private = 10.0.1.0/24, 10.0.2.0/24
  #                      public  = 10.0.101.0/24, 10.0.102.0/24
  private_subnets = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 8, i + 1)]
  public_subnets  = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 8, i + 101)]
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.13"

  name = "${local.name}-vpc"
  cidr = var.vpc_cidr

  azs             = local.azs
  private_subnets = local.private_subnets
  public_subnets  = local.public_subnets
  
  enable_nat_gateway = true
  single_nat_gateway = true

 
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Kubernetes subnet tags 
  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1 
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1 
  }

  tags = local.tags
}
