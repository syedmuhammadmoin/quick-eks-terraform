# Cluster VPC. Subnets are derived from var.vpc_cidr so changing region or
# CIDR only needs one variable:
#   private /20s  -> x.x.0.0, x.x.16.0, x.x.32.0 ...   (worker nodes)
#   public  /24s  -> x.x.240.0, x.x.241.0, ...         (NAT, internet-facing LBs)

data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"] # skip Local Zones / Wavelength
  }
}

locals {
  azs             = slice(data.aws_availability_zones.available.names, 0, var.az_count)
  private_subnets = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 4, i)]
  public_subnets  = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 8, 240 + i)]
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = local.azs
  private_subnets = local.private_subnets
  public_subnets  = local.public_subnets

  enable_nat_gateway = true
  single_nat_gateway = true # cost. Production would be one per AZ.

  enable_dns_hostnames = true
  enable_dns_support   = true

  # EKS uses these tags to discover subnets for load balancers.
  public_subnet_tags  = { "kubernetes.io/role/elb" = 1 }
  private_subnet_tags = { "kubernetes.io/role/internal-elb" = 1 }
}
