#!/bin/bash

# Set your parameters
KEY_NAME="cloudguru"
PEM_FILE="~/.ssh/cloudguru.pem"
INSTANCE_TYPE="t2.medium"
AMI_ID="ami-0261755bbcb8c4a84" # Replace this with your AMI ID
VPC_ID=$(aws ec2 describe-vpcs | jq -r '.Vpcs[0] | .VpcId') # Replace this with your VPC ID
SUBNET_ID="$(aws ec2 describe-subnets | jq -r '.Subnets[0] | .SubnetId')" # Replace this with your subnet ID
SECURITY_GROUP_NAME="k8s-playground"
SECURITY_GROUP_DESC="K8s group that allows all traffic"

echo "Creating key pair..."
# Create a new key pair and save the private key to a .pem file
aws ec2 delete-key-pair --key-name $KEY_NAME || true
rm -f  ~/.ssh/cloudguru.pem || true
aws ec2 create-key-pair --key-name $KEY_NAME --query 'KeyMaterial' --output text --no-cli-pager > ~/.ssh/cloudguru.pem

# Change the .pem file's permissions so it can be used
echo "Updating .pem file permissions..."

chmod 400 ~/.ssh/cloudguru.pem

echo "Creating security group..."

# # Create a new security group and save its GroupId
SECURITY_GROUP_ID=$(aws ec2 create-security-group --group-name $SECURITY_GROUP_NAME --description "$SECURITY_GROUP_DESC" --vpc-id $VPC_ID --query 'GroupId' --output text)

# # Allow all inbound traffic
echo "Allowing all inbound traffic..."
aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_ID --protocol tcp --port 0-65535 --cidr 0.0.0.0/0

# Array of instance tags
INSTANCE_TAGS=("k8s-control" "k8s-worker1" "k8s-worker2")

# Create the hosts.ini and hosts file
echo -n > hosts.ini
echo -n > hosts

# Array of instance tags
INSTANCE_TAGS=("k8s-control" "k8s-worker1" "k8s-worker2")

# Initialize the hosts.ini and hosts files
echo "[control]" > hosts.ini
echo "[worker]" >> hosts.ini
echo -n > scripts/hosts

echo "Creating EC2 instances..."

# Loop over each instance tag
for TAG in ${INSTANCE_TAGS[@]}; do
    # Create a new EC2 instance and save its InstanceId
    INSTANCE_ID=$(aws ec2 run-instances --image-id $AMI_ID --count 1 --instance-type $INSTANCE_TYPE --key-name $KEY_NAME --security-group-ids $SECURITY_GROUP_ID --subnet-id $SUBNET_ID --query 'Instances[*].InstanceId' --output text)

    echo "Tagging instance..."
    # Tag the instance
    aws ec2 create-tags --resources $INSTANCE_ID --tags Key=Name,Value=$TAG

    echo "Waiting for instance to be running..."
    # Wait for the instance to be running
    aws ec2 wait instance-running --instance-ids $INSTANCE_ID

    echo "Retrieving public and private IPs..."
    # Get the public and private IP addresses of the instance
    PUBLIC_IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query 'Reservations[*].Instances[*].PublicIpAddress' --output text)
    PRIVATE_IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query 'Reservations[*].Instances[*].PrivateIpAddress' --output text)

    echo "Updating hosts.ini and hosts files..."
    # Add the public IP to the appropriate group in hosts.ini
    if [ $TAG = "k8s-control" ]; then
        sed -i '' "/\[control\]/a\\
        $PUBLIC_IP host_name=$TAG
        " hosts.ini
    else
        sed -i '' "/\[worker\]/a\\
        $PUBLIC_IP host_name=$TAG
        " hosts.ini
    fi

    # Add the private IP to the hosts file
    echo "$PRIVATE_IP $TAG" >> scripts/hosts
    echo "Instance with tag: $TAG has been successfully created and configured."

done

cat << EOF >> hosts.ini 

[all:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=~/.ssh/cloudguru.pem
EOF

echo "Script execution completed."

