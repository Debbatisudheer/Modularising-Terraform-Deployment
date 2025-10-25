data "terraform_remote_state" "evt_infra" {
  backend = "s3"
  config = {
    region = var.region
    bucket = "${var.account}-state"
    key    = "${var.environment}/${var.service}/infra/terraform.state"
    encrypt = true
  }
}

data "terraform_remote_state" "evt_ingest" {
  backend = "s3"
  config = {
    region = var.region
    bucket = "${var.account}-state"
    key    = "${var.environment}/${var.service}/ingest/terraform.state"
    encrypt = true
  }
}

data "terraform_remote_state" "evt_redis" {
  backend = "s3"
  config = {
    region = var.region
    bucket = "${var.account}-state"
    key    = "${var.environment}/${var.service}/elasticache/terraform.state"
    encrypt = true
  }
}

data "terraform_remote_state" "evt_svcToken" {
  backend = "s3"
  config = {
    region = var.region
    bucket = "${var.account}-state"
    key    = "${var.environment}/${var.service}/eventingServiceToken/terraform.state"
    encrypt = true
  }
}

data "aws_secretsmanager_secret_version" "visibility-eventing-secrets" {
  secret_id = "visibility-eventing@${var.environment}_secrets"
}

data "aws_secretsmanager_secret_version" "datadogkeys" {
  secret_id = "${var.environment}@datadog-key"
}
