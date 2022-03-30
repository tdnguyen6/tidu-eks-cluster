
export AWS_PROFILE=tidunguyen
export KARPENTER_VERSION=v0.7.4
export AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
export CLUSTER_NAME="tidu-cluster"
export SUBNET_IDS=$(aws cloudformation describe-stacks \
  --stack-name eksctl-$CLUSTER_NAME-cluster \
  --query 'Stacks[].Outputs[?OutputKey==`SubnetsPrivate`].OutputValue' \
  --output text)

eksctl delete cluster --name "${CLUSTER_NAME}"
aws cloudformation delete-stack --stack-name "Karpenter-${CLUSTER_NAME}"
aws ec2 describe-launch-templates \
    | jq -r ".LaunchTemplates[].LaunchTemplateName" \
    | grep -i "Karpenter-${CLUSTER_NAME}" \
    | xargs -I{} aws ec2 delete-launch-template --launch-template-name {}
aws iam delete-role --role-name "${CLUSTER_NAME}-karpenter"
aws iam delete-policy --policy-arn "arn:aws:iam::${AWS_ACCOUNT_ID}:policy/KarpenterControllerPolicy-${CLUSTER_NAME}"
