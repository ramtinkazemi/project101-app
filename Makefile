.PHONY: all check-aws build

all: check-aws build deploy rollback

setup-local-env:
ifeq ($(GITHUB_ACTIONS),true)
	@echo "Running on GitHub Actions => Skipping .env.local export
else
	@rm -f .env.local.tmp 2> /dev/null || true
	@sed -E "s/=(['\"])([^'\"]+)(['\"])/=\2/" .env.local > .env.local.tmp
	$(eval include .env.local.tmp)
	$(eval export)
	@echo "Running locally => .env.local variables exported"
endif

check-aws: setup-local-env
	@echo AWS_REGION=$(AWS_REGION)
	@echo AWS_ACCOUNT_ID=$(AWS_ACCOUNT_ID)
	@echo "Checking AWS credentials..."; \
	AWS_USER=$$(aws sts get-caller-identity --output text --query 'Arn'); \
	if [ -z "$${AWS_USER}" ]; then \
		echo "Failed to retrieve AWS identity."; \
		exit 1; \
	else \
		echo "AWS User: $${AWS_USER}"; \
	fi
	
kube-config: check-aws
	@echo CLUSTER_NAME=$(CLUSTER_NAME)
	@if ! kubectl config get-contexts -o name | grep -q "arn:aws:eks:$(AWS_REGION):$(AWS_ACCOUNT_ID):cluster/$(CLUSTER_NAME)"; then \
	    aws eks update-kubeconfig --region $(AWS_REGION) --name $(CLUSTER_NAME); \
	fi

build: check-aws
	@echo "Building Docker image..."
	@echo ECR_REPO=$(ECR_REPO)
	@echo DOCKER_IMAGE_TAG=$(DOCKER_IMAGE_TAG)
	@aws ecr get-login-password --region $(AWS_REGION) | \
	docker login --username AWS --password-stdin $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com ;\
	docker build -t $(ECR_REPO):$(DOCKER_IMAGE_TAG) . ;\
	docker tag $(ECR_REPO):$(DOCKER_IMAGE_TAG) $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(ECR_REPO):$(DOCKER_IMAGE_TAG) ;\
	docker push $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(ECR_REPO):$(DOCKER_IMAGE_TAG)

scan: kube-config
	@echo "Scanning Docker image..."
	@echo ECR_REPO=$(ECR_REPO)
	@echo DOCKER_IMAGE_TAG=$(DOCKER_IMAGE_TAG)
	@aws ecr start-image-scan --repository-name $(ECR_REPO) --image-id imageTag=$(DOCKER_IMAGE_TAG)
	@aws ecr describe-image-scan-findings --repository-name $(ECR_REPO) --image-id imageTag=$(DOCKER_IMAGE_TAG)

deploy: kube-config
	@echo "Deploying ..."
	@echo APP_NAME=$(APP_NAME)
	@echo K8S_NAMESPACE=$(K8S_NAMESPACE)
	@./bin/render.sh app.yaml app.vars > app-rendered.yaml
	@kubectl apply -f app-rendered.yaml
	@kubectl rollout status deployment $(APP_NAME) -n $(K8S_NAMESPACE)

destroy: kube-config
	@echo "Destroying ..."
	@echo APP_NAME=$(APP_NAME)
	@echo K8S_NAMESPACE=$(K8S_NAMESPACE)
	@./bin/render.sh app.yaml app.vars > app-rendered.yaml
	@kubectl delete -f app-rendered.yaml

rollback: kube-config
	@echo "Reverting the last deployment..."
	@kubectl rollout undo deployment $(APP_NAME) -n $(K8S_NAMESPACE)
	@kubectl rollout status deployment $(APP_NAME) -n $(K8S_NAMESPACE)
