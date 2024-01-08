.PHONY: all check-aws build

all: check-aws build deploy rollback

check-aws:
	@echo "Checking AWS credentials..."
	@AWS_IDENTITY=$$(aws sts get-caller-identity --region $$AWS_REGION --output text --query 'Account'); \
	AWS_USER=$$(aws sts get-caller-identity --region $$AWS_REGION --output text --query 'Arn'); \
	if [ -z "$$AWS_IDENTITY" ]; then \
		echo "Failed to retrieve AWS identity."; \
		exit 1; \
	else \
		echo "AWS User: $$AWS_USER"; \
	fi
	
kube-config: check-aws
	@if ! kubectl config get-contexts -o name | grep -q "arn:aws:eks:$(AWS_REGION):$(AWS_ACCOUNT_ID):cluster/$(CLUSTER_NAME)"; then \
	    aws eks update-kubeconfig --region $(AWS_REGION) --name $(CLUSTER_NAME); \
	fi

build: check-aws
	@echo "Building Docker image..."
	@aws ecr get-login-password --region $(AWS_REGION) | \
	docker login --username AWS --password-stdin $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com ;\
	docker build -t $(ECR_REPO):$(IMAGE_TAG) . ;\
	docker tag $(ECR_REPO):$(IMAGE_TAG) $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(ECR_REPO):$(IMAGE_TAG) ;\
	docker push $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(ECR_REPO):$(IMAGE_TAG)

scan: kube-config
	@echo "Scanning Docker image..."
	@aws ecr start-image-scan --repository-name $(ECR_REPO) --image-id imageTag=$(IMAGE_TAG)
	@aws ecr describe-image-scan-findings --repository-name $(ECR_REPO) --image-id imageTag=$(IMAGE_TAG)

deploy: kube-config
	@echo "Deploying ..."
	@./bin/render.sh app.yaml app.vars > app-rendered.yaml
	@kubectl apply -f app-rendered.yaml
	@kubectl rollout status deployment/$(APP_NAME)

destroy: kube-config
	@echo "Destroying ..."
	@./bin/render.sh app.yaml app.vars > app-rendered.yaml
	@kubectl delete -f app-rendered.yaml
	@kubectl rollout status deployment/$(APP_NAME) -n $(APP_K8S_NAMESPACE)

rollback: kube-config
	@echo "Reverting the last deployment..."
	@kubectl rollout undo deployment/$(APP_NAME)
	@kubectl rollout status deployment/$(APP_NAME) -n $(APP_K8S_NAMESPACE)
