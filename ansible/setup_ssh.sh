#!/bin/bash
# Begin setup_ssh.sh - add AWS keys to ssh for ansible commands 

# add login node external ssh key
echo "Note: must use via 'source setup_ssh.sh' to persist"
echo "Starting SSH Agent:"
eval "$(ssh-agent -s)"
ssh-add ../secrets/terraform-hpc-cluster-ssh-key.pem
echo "Available SSH keys:"
ssh-add -l
