variable "region" {
  description = "AWS region."
  type        = string
  default     = "eu-west-1"
}

variable "cluster_name" {
  description = "EKS cluster name. Also used to name the VPC and tag everything."
  type        = string
  default     = "quick-eks"
}

variable "cluster_version" {
  description = "Kubernetes version."
  type        = string
  default     = "1.35"
}

variable "vpc_cidr" {
  description = "VPC CIDR. Must be a /16 - subnets are carved out of it automatically."
  type        = string
  default     = "10.42.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0)) && endswith(var.vpc_cidr, "/16")
    error_message = "vpc_cidr must be a valid /16, e.g. 10.42.0.0/16."
  }
}

variable "az_count" {
  description = "Number of availability zones to spread subnets across."
  type        = number
  default     = 3
}

variable "node_instance_types" {
  description = "Multiple types on one spot node group = multiple capacity pools = fewer interruptions."
  type        = list(string)
  default     = ["t3.medium", "t3a.medium", "t2.medium"]
}

variable "node_desired_size" {
  description = "Desired number of worker nodes."
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum number of worker nodes."
  type        = number
  default     = 3
}

variable "cluster_endpoint_public_access" {
  description = "Expose the Kubernetes API endpoint publicly. Convenient for quick access with kubectl."
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDRs allowed to reach the public API endpoint. Lock this to your IP, e.g. [\"203.0.113.7/32\"]."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
