Pre-Requisites:
    Install terraform 
        Refere this link for more detials:
            https://releases.hashicorp.com/terraform/1.0.0/terraform_1.0.0_windows_amd64.zip
    Install aws cli 
        Refere the following link to install aws cli
            https://awscli.amazonaws.com/AWSCLIV2.msi
Setup the environment:
    Create aws account to host this service
    Untar the given file
    cd via-demo
    Create Program account with ACCESS_KEY and SECRET_KEY
    Configure aws
        aws configure 
    
    Create S3 bucket to store the docker file and app details 
        aws s3 mb s3://<unique bucket name> --region us-east-1
        aws s3 sync web s3://<unique bucket name>
        Note: Update the bucket name in the main.tf at 187.
    Run the terraform scripts to provision complete infra
        terraform init
        terraform plan
        terraform apply
    Get load balance dns
