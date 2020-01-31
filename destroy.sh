#!/bin/sh
terraform plan -destroy -out=tfplan && terraform apply tfplan && rm tfplan