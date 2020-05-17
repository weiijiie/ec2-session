# EC2 Session

Short shell script that automates the work flow of starting a remote AWS EC2 instance, SSH-ing into the instance to perform some tasks, then leaving the session and stopping the instance.

## Prerequisites

- AWS CLI installed and configured with credentials.

## Example

```bash
./ec2-session.sh -i i-xxxxxxxxxxxxxxxxx -k ~/path/to/key.pem -p profile -u ubuntu --wait-stop
```

When run, above command will attempt to start EC2 instance `i-xxxxxxxxxxxxxxxxx` using the credentials as defined in the AWS profile `profile`. It will wait for the instance to be started properly before SSHing into the instance using the key pair `~/path/to/key.pem`. Once the SSH session has terminated properly, the script will attempt to stop the EC2 instance, and wait for the instance to stop properly, before terminating.

## Details

2 sets of credentials are required to use the script:

- AWS access key ID and secret access key for an IAM account with minimally these permissions:
  - `[ "ec2:StartInstances", "ec2:StopInstances", "ec2:DescribeInstances" ]`

- Key pair associated with your EC2 instance to use for SSH.

To obtain the AWS access key ID and secret access key to authenticate with AWS APIs, the script will first attempt to use the AWS profile passed in as parameter, followed by taking the values from the environment variables `$AWS_ACCESS_KEY_ID`, `$AWS_SECRET_ACCESS_KEY`. If those are not set, it will default to using the default profile configured in the AWS CLI.

If the program is interrupted, or the terminal is unexpectedly closed without terminating properly, the instance **may not stop properly**. Be sure to check the status of your instances in your AWS account if that happens, to avoid being billed additional charges.

## Flags

| Flag | Description | Required | Default |
|---|---|---|---|
| `-i | --instance-id` | Instance ID of EC2 instance to be started | yes | none |
| `-k | --key` | Path to private key used to SSH into your EC2 instance | yes | none |
| `-u | --user` | User on EC2 instance to SSH into | yes | none |
| `-p | --profile` | AWS CLI profile to use. Optional | no | specified above |
| `--wait-stop` | Program will wait for EC2 to stop before exiting if enabled | no | disabled |
| `--NoStrictHostKeyChecking` | Disables strict host key checking for SSH. | no | disabled |

