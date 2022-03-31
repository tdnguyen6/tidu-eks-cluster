#!/usr/bin/env bash

# Prequisites
aws
kubectl
eksctl
helm

# On Arch
sudo pacman -S \
  aws-cli-v2-bin
  kubectl \ # alias k
  eksctl \
  helm

yay -S aws-iam-authenticator-bin # from AUR

# environment vars
export AWS_PROFILE=tidunguyen
export KARPENTER_VERSION=v0.7.3
export AWS_DEFAULT_REGION=ap-southeast-1
export AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
export CLUSTER_NAME="tidu-cluster"

# Create eks cluster and its cloudformation stacks:
eksctl create cluster -f - << EOF
---
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
metadata:
  name: ${CLUSTER_NAME}
  region: ${AWS_DEFAULT_REGION}
  version: "1.21"
  tags:
    karpenter.sh/discovery: ${CLUSTER_NAME}

vpc:
  cidr: 172.30.0.0/16

availabilityZones:
  - ap-southeast-1a
  - ap-southeast-1b

managedNodeGroups:
  - instanceType: t3.medium
    amiFamily: AmazonLinux2
    name: ${CLUSTER_NAME}-ng
    availabilityZones:
      - ap-southeast-1a
    desiredCapacity: 1
    minSize: 1
    maxSize: 10
iam:
  withOIDC: true
EOF

# set kubectl context
aws eks update-kubeconfig --name ${CLUSTER_NAME}
kubectl config use-context ${CLUSTER_NAME}

export CLUSTER_ENDPOINT="$(aws eks describe-cluster --name ${CLUSTER_NAME} --query "cluster.endpoint" --output text)"

# KarpenterNode IAM Role
TEMPOUT=$(mktemp)
curl -fsSL https://karpenter.sh/$KARPENTER_VERSION/getting-started/getting-started-with-eksctl/cloudformation.yaml  > $TEMPOUT \
&& aws cloudformation deploy \
  --stack-name "Karpenter-${CLUSTER_NAME}" \
  --template-file "${TEMPOUT}" \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides "ClusterName=${CLUSTER_NAME}"
  

eksctl create iamidentitymapping \
  --username system:node:{{EC2PrivateDNSName}} \
  --cluster "${CLUSTER_NAME}" \
  --arn "arn:aws:iam::${AWS_ACCOUNT_ID}:role/KarpenterNodeRole-${CLUSTER_NAME}" \
  --group system:bootstrappers \
  --group system:nodes

# KarpenterController IAM Role
eksctl create iamserviceaccount \
  --cluster "${CLUSTER_NAME}" --name karpenter --namespace karpenter \
  --role-name "${CLUSTER_NAME}-karpenter" \
  --attach-policy-arn "arn:aws:iam::${AWS_ACCOUNT_ID}:policy/KarpenterControllerPolicy-${CLUSTER_NAME}" \
  --role-only \
  --approve \
  --override-existing-serviceaccounts 

# EC2 Spot Service Linked Role
export KARPENTER_IAM_ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${CLUSTER_NAME}-karpenter"
aws iam create-service-linked-role --aws-service-name spot.amazonaws.com
