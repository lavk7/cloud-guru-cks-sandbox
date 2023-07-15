# Motivation
For cloudguru CKS course, the sandbox environment is temporary. The following script quickly spins up the EKS cluster 
# Pre-requisistes
- Install ansible
- AWS CLI


# Steps
## 1. Configure AWS Credentials with the sandbox access keys
```shell
aws configure
```

## 2. Run ec2 start node
```shell
bash ec2_start_nodes.sh
```

## 3. Run ansible playbook
```shell
ansible-playbook -i hosts.ini  ansible-playbook.yaml
```