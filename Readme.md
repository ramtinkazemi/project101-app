# Application Deployment Management on AWS (App Repo)

This repository in the project focuses on building, deploying, and managing a web application on AWS, specifically on an Elastic Kubernetes Service (EKS) cluster. The Makefile simplifies the process through various commands.

## Makefile Commands

- `check-aws`: Checks AWS credentials to ensure access to AWS services.
- `kube-config`: Configures `kubectl` with EKS cluster context if not already set.
- `build`: Builds a Docker image and pushes it to Amazon ECR.
- `scan`: Scans the Docker image in ECR for vulnerabilities.
- `deploy`: Deploys the application to EKS using Kubernetes manifests.
- `destroy`: Removes the application deployment from the EKS cluster.
- `rollback`: Reverts the application to the previous deployment state in case of deployment issues.

## Usage

1. Set AWS credentials and region environment variables (`AWS_REGION`, `AWS_ACCOUNT_ID`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`).
2. Define Docker and Kubernetes configurations in environment variables (`ECR_REPO`, `IMAGE_TAG`, `CLUSTER_NAME`, `APP_NAME`, `APP_K8S_NAMESPACE`).
3. Use Makefile commands to manage the application lifecycle on EKS:
   - Start with `make check-aws`.
   - Build and push the Docker image using `make build`.
   - Scan the image with `make scan`.
   - Deploy the application using `make deploy`, and if needed, revert changes with `make rollback`.

## Troubleshooting

- Regularly use `make check-aws` for credential verification.
- For deployment issues, use `make rollback` to revert to the last stable state.

## Notes

- The repository is intended for managing the application in the EKS environment.
- The `./bin/render.sh` script is used to render Kubernetes manifests with environment-specific variables.