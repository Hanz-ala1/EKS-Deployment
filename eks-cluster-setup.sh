#!/bin/bash

#Set your name of cluster and the region you want below.
CLUSTER_NAME="demo"
REGION="us-east-1"
echo $CLUSTER_NAME
echo $REGION

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo $AWS_ACCOUNT_ID
#Make the script executable
chmod +x script.sh

# Create a cluster 
eksctl create cluster --name ${CLUSTER_NAME} --region ${REGION} --zones=${REGION}a,${REGION}b,${REGION}c

# update the kubeconfig
aws eks update-kubeconfig --region ${REGION} --name ${CLUSTER_NAME}
#View your worker nodes
kubectl get nodes

#Download the IAM  Policies 
curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.4.7/docs/install/iam_policy.json
#Create IAM policy
aws iam create-policy \
--policy-name AWSLoadBalancerControllerIAMPolicy \
--policy-document file://iam_policy.json

#Assoicate IAM-OIDC Provider 
eksctl utils associate-iam-oidc-provider \
--region ${REGION} \
--cluster ${CLUSTER_NAME} \
--approve

#Create ServiceAccount with IAM ROLE
 eksctl create iamserviceaccount \
--cluster=${CLUSTER_NAME} \
--namespace=kube-system \
--name=aws-load-balancer-controller \
--role-name AmazonEKSLoadBalancerControllerRole \
--attach-policy-arn=arn:aws:iam::${AWS_ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy \
--approve

#HELM chart for Load Balancer Controller
helm repo add eks https://aws.github.io/eks-charts
#Update repo
helm repo update
#Install helm chart 
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
-n kube-system \
--set clusterName=${CLUSTER_NAME} \
--set serviceAccount.create=false \
--set serviceAccount.name=aws-load-balancer-controller

#View your deployment
kubectl get deployment -n kube-system aws-load-balancer-controller

#Apply a sample app to test
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.4.7/docs/examples/2048/2048_full.yaml

#View the ingress and address 
kubectl get ingress -n game-2048