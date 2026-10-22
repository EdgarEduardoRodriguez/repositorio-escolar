#!/bin/bash
set -euo pipefail
export AWS_PAGER=""

REGION="us-east-1"
AUTO_SCALING_GROUP_NAME="repositorio-escolar-p08-asg"

aws autoscaling update-auto-scaling-group \
  --region "$REGION" \
  --auto-scaling-group-name "$AUTO_SCALING_GROUP_NAME" \
  --min-size 1 \
  --desired-capacity 1 \
  --max-size 4

aws autoscaling describe-auto-scaling-groups \
  --region "$REGION" \
  --auto-scaling-group-names "$AUTO_SCALING_GROUP_NAME" \
  --query 'AutoScalingGroups[0].{Min:MinSize,Deseado:DesiredCapacity,Max:MaxSize,Instancias:Instances[].{Id:InstanceId,Estado:LifecycleState,Salud:HealthStatus,AZ:AvailabilityZone}}' \
  --output json \
  --no-cli-pager
