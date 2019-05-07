# concourse-gcp-tf-bootstrap

1. [Concourse task](#usage-bootstrap-task) that can idempotently create a GCP project and bucket to store Terraform state in
1. Concourse task to destroy the GCP project
1. An [optional script](#inception-script) to create a folder, 'inception' project, and service account that can create new projects

## Usage - Bootstrap Task

Look at [example.yml](example.yml). You'll need a [gcs-resource](https://github.com/frodenas/gcs-resource/) instance.

Here's the job from the example pipeline. It should be at the _beginning_ of your pipeline, and run on every commit.

```yaml
jobs:
- name: setup-ci
  plan:
  - get: concourse-gcp-tf-bootstrap
    trigger: true
  - task: bootstrap-terraform
    file: git/tasks/bootstrap.yml
    params:
      BILLING_ACCOUNT_ID: {{billing_account_id}}
      BUCKET_LOCATION: {{bucket_location}}
      FOLDER_NAME: {{folder_name}}
      GCP_CREDENTIALS_JSON: {{gcp_credentials_json}}
      ORGANIZATION_ID: {{organization_id}}
      PROJECT_ID: {{project_id}}
      PROJECT_NAME: {{project_name}}
  - put: tfstate
    params:
      file: tfstate-out/terraform.tfstate
```

If you want to try out the example pipeline and don't like unnecessary typing, fill in `example-vars.yml` with appropriate values, correct the path to credentials in the following command, and then run it:

```terminal
$ fly -t changeme set-pipeline \
  --pipeline example \
  --config example.yml \
  --load-vars-from example-vars.yml \
  --var "$(cat path/to/creds.json)"
```

### Required Parameters

* `billing_account_id` - billing account number to associate the created project with, of the format `DEADD0-D0CAFE-B33F3E`, which you can find with `gcloud alpha billing accounts list`
* `bucket_location` - region to store the bucket in, eg `EU`
* `folder_name` - name of the folder to create projects in, which you can find with `gcloud alpha resource-manager folders list`
* `gcp_credentials_json` - contents of the service account credentials file. If you need to pass this as via `fly`, you can use `--var "gcp_credentials_json=$(cat creds.json)"`
* `organization_id` - numerical ID of the containing organization (`gcloud organizations list`)
* `project_id` - _identifier_ that you want the project to have, that must be globally unique. [See Google Cloud Project documentation for restrictions](https://cloud.google.com/resource-manager/docs/creating-managing-projects#identifying_projects).
* `project_name` - human-readable name for the project to be created

## Why?

Terraform and idempotent Concourse pipelines can be combined to continuously deploy infrastructure-as-code. A pipeline should create a complete and free-standing environment without any human intervention. It's best to have one-project-per-environment so that you can cleanly track and delete the resources used therein.

Automating the creation of a Google Cloud Project using Terraform and Concourse is a bit of a hassle because one needs a project and a bucket to store the Terraform state in. However, you can't use Terraform in your pipeline to create the bucket it depends on, as Terraform will try and _read_ from the bucket that doesn't yet exist.

At EngineerBetter we don't like manual processes or snowflake infrastructure, so we created a reusable automated Concourse task that will create the project and bucket if neither exist, and no-op if they both do, and fail in any other edge case.

## Inception Script

This is entirely optional, and you may already have Service Accounts and Folders set up that you wish to use. **If you don't have these already** then you may want to create them using this script.

```terminal
$ ORG_ID=1234567891012 \
  BILLING_ACCOUNT_ID=DEADD0-D0CAFE-B33F3E \
  FOLDER_NAME=automated-platforms \
  PROJECT_ID=inception \
  ./inception.sh
```

Creates:

* A folder with a given name
* A project called 'inception'
* A service account in the 'inception' project that is able to create new projects

In order to create new projects, you'll need a service account that can create these projects. A service account can't exist outside of a project, so you need an 'inception' project to put the service account in. Additionally, it's best practice when using Google Cloud to place projects in folders such that they can inherit IAM roles.
