AWS Static Website Portfolio – Terraform Project

📌 Project Overview

This project demonstrates deploying and managing AWS infrastructure using Terraform with a remote backend stored in Amazon S3.
The goal of this project is to showcase Infrastructure as Code (IaC) best practices, remote state management, Git workflow integration, and AWS resource provisioning.
This portfolio project is part of my transition into cloud engineering and AWS architecture roles.

🧰 Technologies Used

AWS
Terraform
Amazon S3
Git & GitHub
AWS CloudShell
IAM
Linux CLI

🏗 Architecture Overview

Terraform provisions AWS resources
Remote state is stored in an S3 bucket
Infrastructure is managed declaratively
Version control via GitHub repository

🔐 Remote Backend Configuration

Initially, Terraform state was stored locally.
The backend was later migrated to an S3 remote backend to follow best practices.
Backend Configuration Example:
terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "global/s3/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
  }
}

State Migration
During initialization:
terraform init
Terraform detected existing local state and prompted:
Do you want to copy existing state to the new backend?
Selecting yes migrated the local state to S3.

This ensures:
Centralized state storage
Team collaboration readiness
Improved reliability
Better production readiness

📁 Project Structure

aws-portfolio-static/
│
├── main.tf
├── variables.tf
├── outputs.tf
├── backend.tf
├── .gitignore
└── README.md

🔄 Git Workflow

Initialized repository:
git init
git add .
git commit -m "Initial commit"

Connected to GitHub:
git remote add origin https://github.com/<username>/aws-portfolio-static.git
git push -u origin main

Issues Resolved
Fixed src refspec main does not match any
Resolved .git/config.lock permission issue in CloudShell
Successfully pushed project to GitHub

🛠 Key Learning Outcomes

Implemented Terraform remote backend (S3)
Migrated local Terraform state to S3
Understood Terraform state lifecycle
Troubleshot Git configuration issues in CloudShell
Applied infrastructure version control best practices
Strengthened CLI and AWS troubleshooting skills

🎯 Why This Project Matters

This project demonstrates:
Real-world Infrastructure as Code implementation
Secure and scalable state management
Git version control in cloud environments
Practical AWS + Terraform integration

It reflects production-ready thinking rather than just lab experimentation.

📈 Next Improvements

Planned enhancements:
Add DynamoDB state locking
Add CI/CD pipeline (GitHub Actions)
Implement IAM least-privilege policies
Add custom domain with Route 53
CloudFront distribution
Add automated destroy workflow

👨‍💻 About Me

I’m transitioning into cloud engineering with:
AWS Certified Solutions Architect – Associate
CompTIA Network+
Hands-on AWS + Terraform projects
This repository is part of my active cloud portfolio development.
