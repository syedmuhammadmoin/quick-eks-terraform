#!/usr/bin/env bash
# One-time: create an S3 bucket for Terraform state and write backend.hcl.
#
# Usage: ./scripts/bootstrap-state-bucket.sh [region] [bucket-name]
#   region       defaults to $AWS_REGION, then eu-west-1
#   bucket-name  defaults to tfstate-<account-id>-<region>
#
# Safe to re-run: an existing bucket you own is reused and re-hardened.

set -euo pipefail

REGION="${1:-${AWS_REGION:-eu-west-1}}"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
BUCKET="${2:-tfstate-${ACCOUNT_ID}-${REGION}}"
KEY="quick-eks/terraform.tfstate"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BACKEND_FILE="${ROOT}/backend.hcl"

echo "Account: ${ACCOUNT_ID}"
echo "Region:  ${REGION}"
echo "Bucket:  ${BUCKET}"

if aws s3api head-bucket --bucket "${BUCKET}" 2>/dev/null; then
  echo "Bucket already exists - reusing."
else
  if [[ "${REGION}" == "us-east-1" ]]; then
    aws s3api create-bucket --bucket "${BUCKET}" --region "${REGION}"
  else
    aws s3api create-bucket --bucket "${BUCKET}" --region "${REGION}" \
      --create-bucket-configuration "LocationConstraint=${REGION}"
  fi
fi

# Versioning: lets you recover a clobbered or corrupted state file.
aws s3api put-bucket-versioning --bucket "${BUCKET}" \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption --bucket "${BUCKET}" \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"},"BucketKeyEnabled":true}]}'

aws s3api put-public-access-block --bucket "${BUCKET}" \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

if [[ -f "${BACKEND_FILE}" ]]; then
  echo "backend.hcl already exists - not overwriting. Check it points at ${BUCKET}."
else
  cat > "${BACKEND_FILE}" <<EOF
bucket = "${BUCKET}"
key    = "${KEY}"
region = "${REGION}"
EOF
  echo "Wrote ${BACKEND_FILE}"
fi

echo
echo "Next: make up   (or: terraform init -backend-config=backend.hcl)"
