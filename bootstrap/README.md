# Bootstrap Terraform Repo – S3 Backend + DynamoDB State Locking

Apply this repo **first** to create:

- S3 bucket `djuni-terraform-state`
- DynamoDB table `djuni-terraform-locks`

Usage:

```bash
terraform init
cp terraform.tfvars.example terraform.tfvars   # optional
terraform apply
```
