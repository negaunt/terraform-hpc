#!/bin/bash
# Begin gen_ansible.sh - generate terraform artifacts needed by ansible later
ANS_OUT="../ansible/tf_output.json";
terraform output -json > "$ANS_OUT" 
echo "Wrote terraform output: $ANS_OUT"
