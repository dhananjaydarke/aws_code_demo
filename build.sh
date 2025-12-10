#!/bin/bash
terraform init -reconfigure
terraform fmt -recursive
terraform validate
terraform plan
#terraform apply -auto-approve
