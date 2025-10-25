ACCOUNT = $(shell echo grep "^account" terraform.tfvars | cut -d '=' -f2 | tr -d ' ' |tr -d '"')
ENV = $(shell echo grep "^environment" terraform.tfvars | cut -d '=' -f2 | tr -d ' ' |tr -d '"')
SERVICE = $(shell echo grep "^service" terraform.tfvars | cut -d '=' -f2 | tr -d ' ' | tr -d '"')

GLOBAL_STATE_BUCKET = $(ACCOUNT)-state
TFSTATE_FILE = $(ENV)/$(SERVICE)/eventCollector/terraform.state

ifeq ($(TERRAFORM_BIN_PATH),)
TERRAFORM_BIN_PATH := terraform
endif

.PHONY: check-prereq log-setup setup config plan deploy

# ------------------------------------------------------------------------------
# Pre-requisites
# ------------------------------------------------------------------------------
# Do the following steps prior to running the environment setup
# - Install tools in PATH: terraform
# - Install packages: ssx-controller installed at /usr/local/sm/packages/sse
# ------------------------------------------------------------------------------

check-prereq:
	@echo "check pre-requisites ..."
	command -v $(TERRAFORM_BIN_PATH) >/dev/null 2>&1 || { \
		echo "terraform is not in PATH. Aborting." >&2; exit 1; }

updateipsets:
	python3 createIPSets.py

# ------------------------------------------------------------------------------
# Terraform Commands
# ------------------------------------------------------------------------------

# Set the following environment variables prior to config, plan and apply
# AWS_DEFAULT_REGION, AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY
config: updateipsets
	rm -rf .terraform
	@echo "Terraform remote S3 backend config for terraform state ..."
	$(TERRAFORM_BIN_PATH) init -backend=true \
		-backend-config="bucket=$(GLOBAL_STATE_BUCKET)" \
		-backend-config="key=$(TFSTATE_FILE)" \
		-backend-config="encrypt=1"

plan: config
	@echo "`date +%Y-%m-%dT%H:%M:%S%z`: Terraform plan started ..."
	@echo "Terraform get, plan ..."
	$(TERRAFORM_BIN_PATH) get
	$(TERRAFORM_BIN_PATH) plan
	@echo "`date +%Y-%m-%dT%H:%M:%S%z`: Terraform plan done ..."

deploy:
	@echo "`date +%Y-%m-%dT%H:%M:%S%z`: Terraform apply started ..."
	$(TERRAFORM_BIN_PATH) apply -auto-approve
	rm -f .terraform/terraform.tfstate*
	@echo "`date +%Y-%m-%dT%H:%M:%S%z`: Terraform apply done ..."

jenkins:
	@echo "`date +%Y-%m-%dT%H:%M:%S%z`: Terraform apply started ..."
	$(TERRAFORM_BIN_PATH) apply -input=false -auto-approve
	rm -f .terraform/terraform.tfstate*
	@echo "`date +%Y-%m-%dT%H:%M:%S%z`: Terraform apply done ..."

output: config
	$(TERRAFORM_BIN_PATH) show
	rm -f .terraform/terraform.tfstate*

destroy: plan
	@echo "`date +%Y-%m-%dT%H:%M:%S%z`: Terraform destroy started ..."
	$(TERRAFORM_BIN_PATH) destroy
	rm -rf .terraform
	@echo "`date +%Y-%m-%dT%H:%M:%S%z`: Terraform destroy done ..."
