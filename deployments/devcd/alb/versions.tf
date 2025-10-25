terraform {
  required_version = "{{ terraform_current_version }}"
  required_providers {
    aws = {
      source  = "{{ aws_source }}"
      version = "{{ aws_provider_version }}"
    }
  }
}

provider "aws" {
  region = var.region
}


