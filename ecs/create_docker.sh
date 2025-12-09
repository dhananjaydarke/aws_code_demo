#!/bin/bash

aws ecr create-repository --repository-name students-db-poller --region us-east-1
# 1. Login to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 437147519305.dkr.ecr.us-east-1.amazonaws.com

# 2. Build image
docker build -t students-db-poller db-poller/

# 3. Tag it with full ECR URL
docker tag students-db-poller:latest 437147519305.dkr.ecr.us-east-1.amazonaws.com/students-db-poller:latest

# 4. Push to ECR
docker push 437147519305.dkr.ecr.us-east-1.amazonaws.com/students-db-poller:latest
