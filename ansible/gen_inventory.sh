#!/bin/bash
# Begin gen_inventory.sh - script to generate ansible inventory from terraform outputs

#	echo "$IP ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/terraform-hpc-cluster-ssh-key.pem";

# Ensure jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed."
    exit 1
fi

INV="../ansible/inventory.ini"

echo "Generating Ansible inventory..."

# Get the JSON output from Terraform
TF_OUT=$(terraform output -json)
ROUTER=`terraform output -json | jq -j '.head_node_public_ips.value[]' | head -n 1`;

# Start the inventory file with the head_nodes group
# Using the PUBLIC IPs so you can reach them from your local machine
echo "[head_nodes]" > "$INV"
echo "$TF_OUT" | jq -j '.head_node_public_ips.value[]' >> "$INV"
echo " ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/terraform-hpc-cluster-ssh-key.pem" >> "$INV"

echo "" >> "$INV"

# Add the compute_nodes group
# Using the PRIVATE IPs since they do not have public IPs
echo "[compute_nodes]" >> "$INV"
echo "$TF_OUT" | jq -j '.compute_node_private_ips.value[]' >> "$INV"
echo " ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/terraform-hpc-cluster-ssh-key.pem ansible_ssh_common_args='-o ProxyCommand=\"ssh -i ~/.ssh/terraform-hpc-cluster-ssh-key.pem -W %h:%p -q ubuntu@$ROUTER\"'" >> "$INV"

echo "Success! Inventory written to $INV"
cat "$INV"
