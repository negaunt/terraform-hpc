#!/bin/bash
# Begin get_secrets.sh - script to authenticate and download secrets for running this dev environment  
#   Note: credentials in ./secrets are never commited to the github repo. They have to be downloaded
#     securely by this script when first setup on a dev machine with at 'git clone' or related fetch.


# for now keys are stored in an S3 bucket accessible via 'power user' AWS IAM account,
# with keys being the secret file names and values being the secret file data
S3_BUCKET="negaunt-git-tutorials-292600391949-us-west-2-an"
S3_KEYS="
  gh-terraform-hpc-ssh-key.pem
  gh-terraform-hpc-ssh-key.pub
  terraform-hpc-cluster-ssh-key.pem
"

# get initial creds
aws login
if ! aws sts get-caller-identity; then
	echo "error: aws login failed";
	exit 1;
fi;

for FILE in ${S3_KEYS}; do
	if [ -f "$FILE" ]; then continue; fi
	echo "fetching secret: $FILE"
	aws s3 cp s3://${S3_BUCKET}/${FILE} ./${FILE}
	chmod 600 $FILE
	if [ $? -ne 0 ]; then
		echo "error: aws bucket copy failed for key='${FILE}'"
		exit 1;
	fi;
done;


