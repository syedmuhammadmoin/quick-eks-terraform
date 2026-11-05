# Bare EKS cluster: control plane, core addons, one spot managed node group.
# Anything you want to play with on top (Helm charts, operators, etc.) is
# installed afterwards with kubectl/helm, not by Terraform.

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access       = var.cluster_endpoint_public_access
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs
  cluster_endpoint_private_access      = true

  # Gives the identity running `terraform apply` cluster-admin via an
  # EKS access entry. Without it, kubectl returns 401 after apply.
  enable_cluster_creator_admin_permissions = true

  cluster_addons = {
    coredns        = {}
    kube-proxy     = {}
    vpc-cni        = {}
    metrics-server = {} # needed for `kubectl top` and HPA
  }

  # The metrics.k8s.io extension API is PROXIED: `kubectl top` goes to the
  # API server, which then opens a connection INTO the node subnets to reach
  # the metrics-server pod. The module's defaults do not cover the port the
  # EKS metrics-server addon listens on, so the APIService sits at
  # False (FailedDiscoveryCheck) while the pods themselves look healthy.
  #
  # Verify the target port if `kubectl top` breaks after an addon upgrade -
  # it has changed between metrics-server releases (4443, 10250, 10251):
  #   kubectl get endpoints metrics-server -n kube-system
  #
  # source_cluster_security_group = true means "from the EKS control plane's
  # security group" - the caller is the AWS-managed control plane.
  node_security_group_additional_rules = {
    metrics_server = {
      description                   = "API server to metrics-server for the metrics.k8s.io extension API"
      protocol                      = "tcp"
      from_port                     = 10251
      to_port                       = 10251
      type                          = "ingress"
      source_cluster_security_group = true
    }
  }

  eks_managed_node_groups = {
    ng-spot = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = var.node_instance_types
      capacity_type  = "SPOT"

      min_size     = 1
      max_size     = var.node_max_size
      desired_size = var.node_desired_size

      disk_size = 30
    }
  }
}
