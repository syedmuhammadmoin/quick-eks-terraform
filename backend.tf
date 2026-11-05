# Remote state in S3.
#
# Even for a short-lived cluster, local state is a trap: lose it and you cannot
# run `terraform destroy`, which leaves an EKS cluster, a NAT gateway and a
# VPC full of orphaned ENIs to unpick by hand (and keep paying for).
#
# Partial configuration: bucket/key/region live in backend.hcl, which is
# gitignored so no account-specific names end up in the repo. Create it with
# ./scripts/bootstrap-state-bucket.sh, then:
#
#   terraform init -backend-config=backend.hcl
#
# Locking uses S3 native lockfiles (Terraform >= 1.10). No DynamoDB table.

terraform {
  backend "s3" {
    encrypt      = true
    use_lockfile = true
  }
}
