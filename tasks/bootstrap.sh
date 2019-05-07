#!/bin/bash

set -euo pipefail

: "${BILLING_ACCOUNT_ID:?BILLING_ACCOUNT_ID env var must be provided}"
: "${BUCKET_LOCATION:?BUCKET_LOCATION env var must provide region of bucket to hold Terraform state (eg 'EU')}"
: "${FOLDER_NAME:?FOLDER_NAME env var must provide name of extant folder into which new project will be created}"
: "${GCP_CREDENTIALS_JSON:?GCP_CREDENTIALS_JSON env var must provide contents of credentials file}"
: "${ORGANIZATION_ID:?ORGANIZATION_ID env var must provide numeric organization ID}"
: "${PROJECT_ID:?PROJECT_ID env var must be provided}"
: "${PROJECT_NAME:?PROJECT_NAME env var must provide human-readable name of project to create}"

echo "${GCP_CREDENTIALS_JSON}" > creds.json
gcloud auth activate-service-account --key-file creds.json

matching_project="$(gcloud projects list --format json | jq -r --arg PROJECT_ID "$PROJECT_ID" '.[] | select(.projectId==$PROJECT_ID) | .projectId')"

if [[ $matching_project == *"${PROJECT_ID}"* ]]; then
  buckets="$(gsutil ls -p "${PROJECT_ID}")"

  if [[ $buckets == *"${PROJECT_ID}"* ]]; then
    echo "Existing bucket found for project ${PROJECT_ID}"

    if gsutil -q stat "gs://${PROJECT_ID}/ci/terraform.tfstate"; then
      gsutil cp "gs://${PROJECT_ID}/ci/terraform.tfstate" terraform.tfstate
    else
      echo "Error - project bucket exists, but ci/terraform.tfstate does not"
      exit 1
    fi
  else
    echo "No existing bucket found for project ${PROJECT_ID}, assuming first run"
  fi
else
  echo "No existing project ${PROJECT_ID}, assuming first run"
fi


pushd concourse-gcp-tf-bootstrap/tf
  terraform init

  TF_VAR_billing_account_id="${BILLING_ACCOUNT_ID}" \
    TF_VAR_bucket_location="${BUCKET_LOCATION}" \
    TF_VAR_folder_name="${FOLDER_NAME}" \
    TF_VAR_gcp_creds="${GCP_CREDENTIALS_JSON}" \
    TF_VAR_organization_id="${ORGANIZATION_ID}" \
    TF_VAR_project_id="${PROJECT_ID}" \
    TF_VAR_project_name="${PROJECT_NAME}" \
    terraform apply \
    -auto-approve \
    -input=false \
    -state=../../terraform.tfstate \
    -state-out=../../tfstate-out/terraform.tfstate
popd

