#!/bin/bash

set -euxo pipefail

: "${BILLING_ACCOUNT_ID:?BILLING_ACCOUNT_ID env var must specify the ID of the linked billing account}"
: "${FOLDER_NAME:?FOLDER_NAME env var must specify which folder to place the inception project in}"
: "${ORG_ID:?ORG_ID env var must specify the Google Cloud organisation}"
: "${PROJECT_ID:?PROJECT_ID env var must specify globally unique ID for inception project}"

set +u
if [ -z "$PARENT_FOLDER_ID" ]
then
      echo "\$PARENT_FOLDER_ID was not set, creating a top-level folder"
      folder_parent_param="--organization"
      folder_parent_arg="${ORG_ID}"
else
      echo "\$PARENT_FOLDER_ID set to ${PARENT_FOLDER_ID}, creating nested folder"
      folder_parent_param="--folder"
      folder_parent_arg="${PARENT_FOLDER_ID}"
fi
set -u

FOLDER_ID="$(gcloud resource-manager folders list ${folder_parent_param} "${folder_parent_arg}" --format json | jq -r --arg FOLDER_NAME "${FOLDER_NAME}" '.[] | select(.displayName==$FOLDER_NAME) | .name | ltrimstr("folders/")')"

[[ $FOLDER_ID ]] || \
  gcloud resource-manager folders create --display-name="${FOLDER_NAME}" ${folder_parent_param} "${folder_parent_arg}"

gcloud projects list | grep -q "${PROJECT_ID}" || \
  gcloud projects create "${PROJECT_ID}" ${folder_parent_param} "${folder_parent_arg}"

gcloud beta billing projects link "${PROJECT_ID}" --billing-account "${BILLING_ACCOUNT_ID}"

gcloud iam service-accounts list --project "${PROJECT_ID}" | grep -q "Inception User" || \
  gcloud iam service-accounts create inception --display-name "Inception User" --project "${PROJECT_ID}"

gcloud iam service-accounts keys create "${PROJECT_ID}.json" \
  --iam-account "inception@${PROJECT_ID}.iam.gserviceaccount.com" \
  --project "${PROJECT_ID}"

gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member "serviceAccount:inception@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role roles/viewer
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member "serviceAccount:inception@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role roles/storage.admin

gcloud services enable cloudresourcemanager.googleapis.com \
  --project "${PROJECT_ID}"
gcloud services enable cloudbilling.googleapis.com \
  --project "${PROJECT_ID}"
gcloud services enable iam.googleapis.com \
  --project "${PROJECT_ID}"
gcloud services enable compute.googleapis.com \
  --project "${PROJECT_ID}"

gcloud organizations add-iam-policy-binding "${ORG_ID}" \
  --member "serviceAccount:inception@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role roles/resourcemanager.projectCreator
gcloud organizations add-iam-policy-binding "${ORG_ID}" \
  --member "serviceAccount:inception@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role roles/billing.user
gcloud organizations add-iam-policy-binding "${ORG_ID}" \
  --member "serviceAccount:inception@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role roles/billing.viewer
gcloud organizations add-iam-policy-binding "${ORG_ID}" \
  --member "serviceAccount:inception@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role roles/resourcemanager.folderViewer

echo Created folder "${FOLDER_NAME}", project "${PROJECT_ID}" and service account "inception@${PROJECT_ID}.iam.gserviceaccount.com"
