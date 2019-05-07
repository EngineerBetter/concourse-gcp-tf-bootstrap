#!/bin/bash

set -euo pipefail

: "${BILLING_ACCOUNT_ID:?BILLING_ACCOUNT_ID env var must be provided}"
: "${BUCKET_LOCATION:?BUCKET_LOCATION env var must provide region of bucket to hold Terraform state (eg 'EU')}"
: "${FOLDER_NAME:?FOLDER_NAME env var must provide name of extant folder into which new project will be created}"
: "${GCP_CREDENTIALS_JSON:?GCP_CREDENTIALS_JSON env var must provide contents of credentials file}"
: "${ORGANIZATION_ID:?ORGANIZATION_ID env var must provide numeric organization ID}"
: "${PROJECT_ID:?PROJECT_ID env var must be provided}"
: "${PROJECT_NAME:?PROJECT_NAME env var must provide human-readable name of project to create}"

pushd concourse-gcp-tf-bootstrap/tf
  terraform init

  TF_VAR_billing_account_id="${BILLING_ACCOUNT_ID}" \
    TF_VAR_bucket_location="${BUCKET_LOCATION}" \
    TF_VAR_folder_name="${FOLDER_NAME}" \
    TF_VAR_gcp_creds="${GCP_CREDENTIALS_JSON}" \
    TF_VAR_organization_id="${ORGANIZATION_ID}" \
    TF_VAR_project_id="${PROJECT_ID}" \
    TF_VAR_project_name="${PROJECT_NAME}" \
    terraform destroy \
    -auto-approve \
    -input=false \
    -state=../../tfstate/terraform.tfstate
popd

