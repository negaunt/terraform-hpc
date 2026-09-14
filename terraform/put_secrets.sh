#!/bin/bash
# Begin put_secrets.sh - script to authenticate and upload secrets for running this dev environment  
#   Note: credentials in ./secrets are never commited to the github repo. They have to be downloaded
#     securely by this script when first setup on a dev machine with at 'git clone' or related fetch.


# for now keys are stored in an S3 bucket accessible via 'power user' AWS IAM account,
# with keys being the secret file names and values being the secret file data
S3_BUCKET="negaunt-git-tutorials-292600391949-us-west-2-an"
S3_KEYS="
terraform.tfvars
"

# put creds
aws login
if ! aws sts get-caller-identity; then
	echo "error: aws login failed";
	exit 1;
fi;

for FILE in ${S3_KEYS}; do
	echo "saving secret: $FILE"
	aws s3 cp ./${FILE} s3://${S3_BUCKET}/${FILE}
	if [ $? -ne 0 ]; then
		echo "error: aws bucket copy failed for key='${FILE}'"
		exit 1;
	fi;
done;


