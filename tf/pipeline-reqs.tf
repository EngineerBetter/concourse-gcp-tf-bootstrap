variable "billing_account_id" {}
variable "bucket_location" {}
variable "folder_name" {}
variable "gcp_creds" {}
variable "organization_id" {}
variable "project_id" {}
variable "project_name" {}

provider "google" {
  credentials = "${var.gcp_creds}"
}

data "google_active_folder" "folder" {
  display_name = "${var.folder_name}"
  parent       = "organizations/${var.organization_id}"
}

resource "google_project" "automated_project" {
  name            = "${var.project_name}"
  project_id      = "${var.project_id}"
  folder_id       = "${data.google_active_folder.folder.name}"
  billing_account = "${var.billing_account_id}"
}

resource "google_storage_bucket" "ci" {
  name          = "${var.project_id}"
  location      = "${var.bucket_location}"
  project       = "${google_project.automated_project.project_id}"
  force_destroy = true

  versioning {
    enabled = true
  }
}
