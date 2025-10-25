terraform {
  backend "s3" {
    bucket  = "{{ account }}-state"
    key     = "{{ environment }}/{{ service }}/{{deployments}}/terraform.state"
    region  = "{{ aws_region }}"
    encrypt = 1
  }
}
