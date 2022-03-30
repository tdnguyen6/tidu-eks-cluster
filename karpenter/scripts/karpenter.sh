#!/usr/bin/env bash

helm repo add karpenter https://charts.karpenter.sh/
helm repo update

export KARPENTER_VERSION=v0.7.3
export AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
export CLUSTER_NAME="tidu-cluster"
export SUBNET_IDS=$(aws cloudformation describe-stacks \
  --stack-name eksctl-$CLUSTER_NAME-cluster \
  --query 'Stacks[].Outputs[?OutputKey==`SubnetsPrivate`].OutputValue' \
  --output text)
export CLUSTER_ENDPOINT="$(aws eks describe-cluster --name ${CLUSTER_NAME} --query "cluster.endpoint" --output text)"
export KARPENTER_IAM_ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${CLUSTER_NAME}-karpenter"

helm upgrade --install --namespace karpenter --create-namespace \
  karpenter karpenter/karpenter \
  --version $KARPENTER_VERSION \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=${KARPENTER_IAM_ROLE_ARN} \
  --set clusterName=${CLUSTER_NAME} \
  --set clusterEndpoint=${CLUSTER_ENDPOINT} \
  --set aws.defaultInstanceProfile=KarpenterNodeInstanceProfile-${CLUSTER_NAME} \
  --set logLevel=debug \
  --wait # for the defaulting webhook to install before creating a Provisioner
