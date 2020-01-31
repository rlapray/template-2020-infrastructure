# template-2020-infrastructure

## Intro

This project is an easy to read terraform template to build a base infrastructure using :
- VPC,  public / private subnets, internetgateway, NATs, Elastic IP.
- ECS Cluster
- ECS tasks with FARGATE
- Application Load Balancer doing HTTPS and routing
- CodePipeline for each service (source -> build and test -> staging -> approval -> production)
- ECR
- CodeDeploy (blue green deployment)
- AppMesh (inter-tasks communication, weighted routing)
- Serverless RDS
- AWS Parameter Store with secured parameters
- Lambdas
- CodePipeline for each lambda (source -> build -> staging -> approval -> production)

These components are organized as modules, with parameters meant to be changed (advertised as locals and between variables comments sections) and static parameters.

For example, with only one parameter each time you can :
- Create the complete production environment but disable costly networking components (and access) before prime time.
- Use 1 NAT for an entire VPC or 1 NAT in each availability zone.
- Enable a serverless postgresql, providing credentials to the service in a normalized and secured way.

## TL;DR => make it work

Create a terraform.tfvars like this : 

```
region             = "eu-west-1"
availability_zones = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]

vpc_cidr             = "10.0.0.0/16"
public_subnets_cidr  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
private_subnets_cidr = ["10.0.10.0/24", "10.0.20.0/24", "10.0.30.0/24"]

staging_subdomain          = "staging.myproduct.fr"
staging_certificate_arn    = "#staging certificate ARN#"
production_subdomain       = "production.myproduct.fr"
production_certificate_arn = "#production certificate ARN#"
github_token               = "#github token#"
route53_zone_id            = "#hosted zone id#"
```

Then you're good to go.

## Assistance

### Destroy the infrastructure

Terraform right now (feb 2020) has a bug in the destroy command. Use the script to destroy everything.

### Creating the hosted zone

One requirement is to have a hosted zone attached to your domain name.

If you already have a domain name for another provider, you can do the following :

- create a hosted zone in route53 for your domain name.
- go to your domain provider dns server list.
- replace theses servers by the ones from the AWS hosted zone.
- apply and wait.

Example for ovh : https://eshlox.net/2017/12/29/how-to-create-aws-route53-hosted-zone-using-domain-from-ovh

### Certificates

Go to certificate manager, and make one for each environment.
