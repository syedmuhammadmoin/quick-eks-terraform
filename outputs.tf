output "region" {
  value = var.region
}

output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "vpc_cidr" {
  value = var.vpc_cidr
}

output "private_subnet_ids" {
  value = module.vpc.private_subnets
}

output "node_security_group_id" {
  value = module.eks.node_security_group_id
}

output "kubeconfig_cmd" {
  value = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}
