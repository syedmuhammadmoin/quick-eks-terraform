# quick-eks

Quick EKS: spin up an EKS cluster when you need one and tear it down when
you're done. A bare cluster in its own VPC, cheap spot nodes, and one-command
up/down.

## What this creates

| Resource | Default |
|---|---|
| Region | `eu-west-1` (variable) |
| VPC | `10.42.0.0/16` across 3 AZs |
| Private subnets | `/20` per AZ: `10.42.0.0`, `10.42.16.0`, `10.42.32.0` (worker nodes) |
| Public subnets | `/24` per AZ: `10.42.240.0`, `.241.0`, `.242.0` (NAT, public LBs) |
| NAT | Single gateway (cost) |
| Cluster | `quick-eks`, Kubernetes 1.35 |
| Endpoint | Public + private (restrict with `cluster_endpoint_public_access_cidrs`) |
| Nodes | 2 x spot `t3.medium`/`t3a.medium`/`t2.medium`, 30 GB, AL2023 (scales 1–3) |
| Addons | vpc-cni, coredns, kube-proxy, metrics-server |
| Access | The IAM identity that runs `apply` gets cluster-admin (EKS access entry) |

Not included: EBS CSI driver, AWS Load Balancer Controller, Karpenter, ingress, and so on.
Install what you need on top with Helm.

## Prerequisites

- Terraform >= 1.10
- AWS CLI v2, authenticated against the account you want to use (`aws sts get-caller-identity`)
- `kubectl`

## Step 0: state bucket (once per account)

State lives in S3, not on your laptop. If you lose local state you can't
`terraform destroy`, and you end up hand-deleting an EKS cluster, a NAT
gateway and a VPC full of orphaned ENIs.

    make bootstrap                 # or: ./scripts/bootstrap-state-bucket.sh [region] [bucket]

This creates a versioned, encrypted, private bucket named
`tfstate-<account-id>-<region>` and writes `backend.hcl` (gitignored). State
locking uses S3 native lockfiles, so you don't need a DynamoDB table.

## Optional: customise

    cp terraform.tfvars.example terraform.tfvars

At minimum, consider locking the API endpoint to your IP:

    cluster_endpoint_public_access_cidrs = ["<your-ip>/32"]   # curl -s https://checkip.amazonaws.com

If you change `vpc_cidr`, check that nothing in the account overlaps it:

    aws ec2 describe-vpcs --query 'Vpcs[].[VpcId,CidrBlock]' --output table

## Up

    make up                        # init + plan + apply + kubeconfig + verify (~15-20 min)

Or by hand:

    terraform init -backend-config=backend.hcl
    terraform plan -out=tfplan
    terraform apply tfplan
    $(terraform output -raw kubeconfig_cmd)

## Verify

    make verify
    # kubectl get nodes -o wide    -> 2 Ready, private IPs in 10.42.x
    # kubectl get pods -A          -> coredns, aws-node, kube-proxy, metrics-server Running
    # kubectl top nodes            -> proves metrics-server works

If `kubectl top nodes` keeps failing, see the metrics-server note in `eks.tf`.

## Down

    make down

This first deletes Kubernetes-created AWS resources (LoadBalancer services,
ingresses, PVCs), then runs `terraform destroy`. Order matters: if an ELB or
EBS volume is still around, the VPC delete blocks for about 20 minutes and then
fails. This is the most common EKS teardown failure.

If you installed anything else that creates AWS resources (for example, the
AWS Load Balancer Controller), uninstall it before `make down`.

The state bucket is kept so you can run `make up` again later.

## Cost

Roughly **$4-6/day** (~$0.20/hr) while it's running: EKS control plane
$0.10/hr, one NAT gateway plus its public IP, and two spot t3.medium nodes.
NAT data processing comes on top. **Destroy it when you're done.**

## Make targets

    make help
