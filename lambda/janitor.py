import boto3
import os
from datetime import datetime, timedelta, timezone

def lambda_handler(event, context):
    ec2 = boto3.client('ec2')
    sns = boto3.client('sns')
    topic_arn = os.environ.get('SNS_TOPIC_ARN')
    
    report = ["--- Cloud Janitor Daily Report ---"]
    
    # 1. Cleanup Unattached EBS Volumes
    vols = ec2.describe_volumes(Filters=[{'Name': 'status', 'Values': ['available']}])
    for vol in vols['Volumes']:
        vid = vol['VolumeId']
        ec2.delete_volume(VolumeId=vid)
        report.append(f"Deleted idle volume: {vid}")

    # 2. Cleanup Old Snapshots (>30 days)
    cutoff = datetime.now(timezone.utc) - timedelta(days=30)
    snaps = ec2.describe_snapshots(OwnerIds=['self'])
    for snap in snaps['Snapshots']:
        if snap['StartTime'] < cutoff:
            sid = snap['SnapshotId']
            ec2.delete_snapshot(SnapshotId=sid)
            report.append(f"Deleted old snapshot: {sid}")

    # 3. Send Summary via SNS
    if len(report) > 1:
        summary = "\n".join(report)
        sns.publish(TopicArn=topic_arn, Message=summary, Subject="AWS Cleanup Success")
    
    return {"status": "cleaned"}