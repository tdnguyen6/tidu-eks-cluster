REGION=ap-southeast-1
CLUSTER=tidu-cluster
AWS_ACCOUNT_ID=$$(aws sts get-caller-identity --query Account --output text)

iam-sa-albc:
	eksctl utils associate-iam-oidc-provider \
    --region $(REGION) \
    --cluster $(CLUSTER) \
    --approve
	curl -o /tmp/iam-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json
	# aws iam create-policy \
  #   --policy-name AWSLoadBalancerControllerIAMPolicy \
  #   --policy-document file:///tmp/iam-policy.json
	eksctl create iamserviceaccount \
		--cluster=$(CLUSTER) \
		--namespace=kube-system \
		--name=aws-load-balancer-controller \
		--attach-policy-arn=arn:aws:iam::$(AWS_ACCOUNT_ID):policy/AWSLoadBalancerControllerIAMPolicy \
		--approve

view:
	kubectl kustomize . --enable-helm

apply:
	kubectl kustomize . --enable-helm | kubectl apply -f -

delete:
	kubectl kustomize . --enable-helm | kubectl delete -f -

iam-karpenter:
	TEMPOUT=$$(mktemp);\
	KARPENTER_VERSION=v0.7.3;\
	echo $$TEMPOUT ;\
	curl -fsSL https://karpenter.sh/$$KARPENTER_VERSION/getting-started/getting-started-with-eksctl/cloudformation.yaml  > $$TEMPOUT \
	&& aws cloudformation deploy \
		--stack-name "Karpenter-$(CLUSTER)" \
		--template-file $$TEMPOUT \
		--capabilities CAPABILITY_NAMED_IAM \
		--parameter-overrides "ClusterName=$(CLUSTER)" ;\
		

	eksctl create iamidentitymapping \
		--username system:node:{{EC2PrivateDNSName}} \
		--cluster "$(CLUSTER)" \
		--arn "arn:aws:iam::$(AWS_ACCOUNT_ID):role/KarpenterNodeRole-$(CLUSTER)" \
		--group system:bootstrappers \
		--group system:nodes ;\

	# KarpenterController IAM Role
	eksctl create iamserviceaccount \
		--cluster "$(CLUSTER)" --name karpenter --namespace karpenter \
		--role-name "$(CLUSTER)-karpenter" \
		--attach-policy-arn "arn:aws:iam::$(AWS_ACCOUNT_ID):policy/KarpenterControllerPolicy-$(CLUSTER)" \
		--role-only \
		--approve \
		--override-existing-serviceaccounts ;\

	# # EC2 Spot Service Linked Role
	# export KARPENTER_IAM_ROLE_ARN="arn:aws:iam::$(AWS_ACCOUNT_ID):role/$(CLUSTER)-karpenter"
	aws iam create-service-linked-role --aws-service-name spot.amazonaws.com

clean:
	AWS_PROFILE=tidunguyen ;\
	KARPENTER_VERSION=v0.7.3 ;\
	SUBNET_IDS=$(aws cloudformation describe-stacks \
		--stack-name eksctl-$$CLUSTER-cluster \
		--query 'Stacks[].Outputs[?OutputKey==`SubnetsPrivate`].OutputValue' \
		--output text) ;\

	eksctl delete cluster --name "$(CLUSTER)"
	aws cloudformation delete-stack --stack-name "Karpenter-$(CLUSTER)"
	aws ec2 describe-launch-templates \
			| jq -r ".LaunchTemplates[].LaunchTemplateName" \
			| grep -i "Karpenter-$(CLUSTER)" \
			| xargs -I{} aws ec2 delete-launch-template --launch-template-name {}
	aws iam delete-role --role-name "$(CLUSTER)-karpenter"
	aws iam delete-policy --policy-arn "arn:aws:iam::$(AWS_ACCOUNT_ID):policy/KarpenterControllerPolicy-$(CLUSTER)"\
