.PHONY: all check-aws build

all: check-aws build deploy rollback

check-aws:
	@echo "Checking AWS credentials..."
	@AWS_IDENTITY=$$(aws sts get-caller-identity --output text --query 'Account'); \
	AWS_USER=$$(aws sts get-caller-identity --output text --query 'Arn'); \
	if [ -z "$$AWS_IDENTITY" ]; then \
		echo "Failed to retrieve AWS identity."; \
		exit 1; \
	else \
		echo "AWS User: $$AWS_USER"; \
	fi
	
kube-config: check-aws
	@if ! kubectl config get-contexts -o name | grep -q "arn:aws:eks:$(AWS_REGION):$(AWS_ACCOUNT_ID):cluster/$(APP_NAME)"; then \
	    aws eks update-kubeconfig --region $(AWS_REGION) --name $(APP_NAME); \
	fi

build: check-aws
	@echo "Building Docker image..."
	@aws ecr get-login-password --region $(AWS_REGION) | \
	docker login --username AWS --password-stdin $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com; \
	docker build -t $(APP_NAME):$(IMAGE_TAG) . ;\
	docker tag $(APP_NAME):$(IMAGE_TAG) $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(APP_NAME):$(IMAGE_TAG)
	docker push $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(APP_NAME):$(IMAGE_TAG)

scan: kube-config
	@echo "Scanning Docker image..."
	@aws ecr start-image-scan --repository-name $(APP_NAME) --image-id imageTag=$(IMAGE_TAG)
	@aws ecr describe-image-scan-findings --repository-name $(APP_NAME) --image-id imageTag=$(IMAGE_TAG)

deploy: kube-config
	@echo "Deploying ..."
	@./bin/render.sh app.yaml app.vars > app-rendered.yaml
	@kubectl apply -f app-rendered.yaml
	@kubectl rollout status deployment/$(APP_NAME)

rollback: kube-config
	@echo "Reverting the last deployment..."
	@kubectl rollout undo deployment/$(APP_NAME)
	@kubectl rollout status deployment/$(APP_NAME)
