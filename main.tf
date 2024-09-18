locals {
	project		= var.gcp_project_id
	region		= var.gcp_region
	upload_file	= var.upload_file
}

data "google_storage_bucket" "input" {
	project	= local.project
	name	= "${local.project}-input"
}

data "google_storage_bucket" "output" {
	project	= local.project
	name	= "${local.project}-output"
}

resource "google_storage_bucket_object" "upload" {
	name		= local.upload_file
	source		= local.upload_file
	content_type	= "text/plain"
	bucket		= data.google_storage_bucket.input.id
}

locals {
	url = "https://storage.googleapis.com/${data.google_storage_bucket.output.name}/${local.upload_file}.iso"
}
output "url" {
	value = "https://storage.googleapis.com/${data.google_storage_bucket.output.name}/${local.upload_file}.iso"
}

resource "time_sleep" "pipeline-delay" {
        create_duration = "60s"
        depends_on = [
                google_storage_bucket_object.upload
        ]
}

# download boot.iso
resource "null_resource" "download-iso" {
        triggers        = {
                url             = local.url
                path            = "${local.upload_file}.iso"
                always_run      = timestamp()
        }
        provisioner "local-exec" {
                interpreter     = ["/bin/bash", "-c"]
                command         = <<-EOT
                        echo "CURL [ ${self.triggers.url} >> ${self.triggers.path} ]"
                        curl -fLo ${self.triggers.path} ${self.triggers.url}
                EOT
        }
        provisioner "local-exec" {
                when    = destroy
                command = <<-EOT
                        echo "REMOVE ${self.triggers.path}"
                        rm ${self.triggers.path} &>/dev/null
                EOT
        }
        depends_on = [
                time_sleep.pipeline-delay
        ]
}
