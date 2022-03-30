.ONESHELL:
.SILENT:
REGION=ap-southeast-1
CLUSTER=tidu-cluster
AWS_ACCOUNT_ID:=$(shell aws sts get-caller-identity --query Account --output text)

iam-sa-albc:
	# eksctl utils associate-iam-oidc-provider \
  #   --region $(REGION) \
  #   --cluster $(CLUSTER) \
  #   --approve
	curl -o /tmp/iam-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json
	aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file:///tmp/iam-policy.json
	eksctl create iamserviceaccount \
		--cluster=$(CLUSTER) \
		--namespace=kube-system \
		--name=aws-load-balancer-controller \
		--attach-policy-arn=arn:aws:iam::$(AWS_ACCOUNT_ID):policy/AWSLoadBalancerControllerIAMPolicy \
		--override-existing-serviceaccounts \
		--approve

iam-sa-clean:
	eksctl delete iamserviceaccount aws-load-balancer-controller --cluster $(CLUSTER)
	aws iam delete-policy --policy-arn arn:aws:iam::$(AWS_ACCOUNT_ID):policy/AWSLoadBalancerControllerIAMPolicy
	OIDCURL=$$(aws eks describe-cluster --name $(CLUSTER) --output json | jq -r .cluster.identity.oidc.issuer | sed -e "s*https://**") &&	aws iam delete-open-id-connect-provider --open-id-connect-provider-arn arn:aws:iam::$(AWS_ACCOUNT_ID):oidc-provider/$$OIDCURL

view:
	kubectl kustomize . --enable-helm

apply:
	kubectl kustomize . --enable-helm | kubectl apply -f -

delete:
	kubectl kustomize . --enable-helm | kubectl delete -f -

karpenter-config:
	./karpenter/scripts/install.sh

karpenter-clean:
	./karpenter/scripts/cleanup.sh

test:
	echo $(AWS_ACCOUNT_ID)
	echo $(AWS_ACCOUNT_ID)
	echo $(CLUSTER)

he: .ONESHELL
	X=$$(date)
	echo $$X

t:
	X=$$(date)
	echo $$X
