# tidu-eks-cluster

Steps:

make karpenter-config

make iam albc

change albc arn

make apply

add inbound rule to security group

tag security group for karpenter discovery

configure vpc peering:
  - peering interface
  - route table

create kong-http1 target group

change kong cluster endpoint

create alb-internal point to kong-http1 listen on port 443 with tls

create alb-http and alb-https target group point to alb-internal

create nlb-external point to alb-http and alb-https

configure route53 private zone to point to 2 subnets

configure route53 public and private zone dns
