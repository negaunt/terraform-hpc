#!/bin/bash
# Begin check_ssh_key.sh - check SHA1 of ansible public SSH key 
openssl pkcs8 -in ../secrets/terraform-hpc-cluster-ssh-key.pem -inform PEM -outform DER -topk8 -nocrypt | openssl sha1 -c
