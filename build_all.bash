#!/bin/bash
cd /home/ddarke/GitHub/aws_students_full_project_with_backend_full
build_all ()
{
	pwd
	terraform init -reconfigure
	terraform fmt -recursive
	terraform validate
	terraform plan
	#echo terraform apply -auto-approve
	}


ALL_REPO="bootstrap network hosted-zones ecs rds-mssql  spa"

for current_repo in ${ALL_REPO}
do
	cd /home/ddarke/GitHub/aws_students_full_project_with_backend_full/${current_repo}
	build_all
done
