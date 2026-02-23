# Cloud Janitor

An automated AWS resource cleanup solution that helps reduce cloud costs by removing unused EBS volumes and old snapshots. Runs daily as a serverless Lambda function with email notifications.

## Features

- **Unattached EBS Volume Cleanup** - Automatically deletes EBS volumes in `available` state (not attached to any EC2 instance)
- **Old Snapshot Cleanup** - Removes EBS snapshots older than 30 days
- **Daily Email Reports** - Sends cleanup summaries via SNS email notifications
- **Scheduled Execution** - Runs automatically every day at midnight UTC
- **Infrastructure as Code** - Fully managed with Terraform

## Architecture

```
CloudWatch Events (daily cron) → Lambda → EC2 API (cleanup) → SNS (notifications)
```

## Prerequisites

- AWS Account with appropriate permissions
- [Terraform](https://www.terraform.io/downloads) >= 1.0
- AWS CLI configured with credentials
- S3 bucket for Terraform state (or modify backend configuration)
- DynamoDB table for state locking (optional)

## Deployment

1. **Clone the repository**

   ```bash
   git clone <repository-url>
   cd cloud-janitor
   ```

2. **Configure variables**

   Edit `main.tf` and update:
   - S3 backend bucket name (line 3)
   - SNS email endpoint (line 23) - replace with your email address

3. **Initialize Terraform**

   ```bash
   terraform init
   ```

4. **Review the plan**

   ```bash
   terraform plan
   ```

5. **Deploy the infrastructure**

   ```bash
   terraform apply
   ```

6. **Confirm SNS subscription**

   Check your email and confirm the SNS subscription to receive cleanup reports.

## Configuration

| Setting             | Location            | Default               |
| ------------------- | ------------------- | --------------------- |
| AWS Region          | `main.tf`           | `ap-southeast-1`      |
| Schedule            | `main.tf`           | Daily at midnight UTC |
| Snapshot retention  | `lambda/janitor.py` | 30 days               |
| Email notifications | `main.tf`           | Configure your email  |

## Resources Created

- **Lambda Function** - `CloudJanitor` (Python 3.12)
- **IAM Role & Policy** - Permissions for EC2, SNS, and CloudWatch Logs
- **SNS Topic** - `cloud-janitor-alerts` for email notifications
- **CloudWatch Event Rule** - Daily trigger schedule

## Permissions

The Lambda function requires these IAM permissions:

- `ec2:DescribeVolumes` / `ec2:DeleteVolume`
- `ec2:DescribeSnapshots` / `ec2:DeleteSnapshot`
- `sns:Publish`
- `logs:CreateLogGroup` / `logs:CreateLogStream` / `logs:PutLogEvents`

## Testing

To manually test the Lambda function:

```bash
aws lambda invoke --function-name CloudJanitor output.json
cat output.json
```

## Cleanup

To remove all deployed resources:

```bash
terraform destroy
```

## Cost

This solution is designed to be cost-effective:

- Lambda free tier includes 1M requests/month
- SNS email notifications are free
- CloudWatch Events are free for this use case

## License

MIT
