#!/bin/bash
set -euo pipefail
export AWS_PAGER=""

REGION="us-east-1"
VPC_ID="vpc-00479773276bc1289"
SUBNET_1="subnet-062992877223c5c32"
SUBNET_2="subnet-0e09186ec3792e7a7"
AMI_ID="ami-0567589d25e06853e"
INSTANCE_TYPE="t3.micro"
INSTANCE_PROFILE="Rol-EC2-Almacenamiento-TheBoys"

PREFIX="repositorio-escolar-p08"
ALB_SG_NAME="${PREFIX}-alb-sg"
WEB_SG_NAME="${PREFIX}-web-sg"
TARGET_GROUP_NAME="repositorio-p08-tg"
LOAD_BALANCER_NAME="repositorio-p08-alb"
LAUNCH_TEMPLATE_NAME="repositorio-escolar-p08-lt"
AUTO_SCALING_GROUP_NAME="repositorio-escolar-p08-asg"
SCALING_POLICY_NAME="repositorio-escolar-p08-cpu50"

tag_spec() {
  local resource_type="$1"
  printf 'ResourceType=%s,Tags=[{Key=Name,Value=%s},{Key=proyecto,Value=Repositorio-escolar},{Key=equipo,Value=The-Boys},{Key=practica,Value=08},{Key=ambiente,Value=dev}]' "$resource_type" "$PREFIX"
}

ALB_SG_ID=$(aws ec2 create-security-group \
  --region "$REGION" \
  --group-name "$ALB_SG_NAME" \
  --description "HTTP publico para ALB de practica 08" \
  --vpc-id "$VPC_ID" \
  --tag-specifications "$(tag_spec security-group)" \
  --query GroupId --output text)

aws ec2 authorize-security-group-ingress \
  --region "$REGION" \
  --group-id "$ALB_SG_ID" \
  --protocol tcp --port 80 --cidr 0.0.0.0/0

WEB_SG_ID=$(aws ec2 create-security-group \
  --region "$REGION" \
  --group-name "$WEB_SG_NAME" \
  --description "HTTP solo desde ALB para practica 08" \
  --vpc-id "$VPC_ID" \
  --tag-specifications "$(tag_spec security-group)" \
  --query GroupId --output text)

aws ec2 authorize-security-group-ingress \
  --region "$REGION" \
  --group-id "$WEB_SG_ID" \
  --ip-permissions "IpProtocol=tcp,FromPort=80,ToPort=80,UserIdGroupPairs=[{GroupId=${ALB_SG_ID},Description=Solo-desde-ALB-P08}]"

USER_DATA_B64=$(base64 -w 0 user-data.sh)
jq -n \
  --arg image "$AMI_ID" \
  --arg type "$INSTANCE_TYPE" \
  --arg profile "$INSTANCE_PROFILE" \
  --arg sg "$WEB_SG_ID" \
  --arg userdata "$USER_DATA_B64" \
  '{
    ImageId: $image,
    InstanceType: $type,
    IamInstanceProfile: {Name: $profile},
    NetworkInterfaces: [{
      DeviceIndex: 0,
      AssociatePublicIpAddress: true,
      DeleteOnTermination: true,
      Groups: [$sg]
    }],
    UserData: $userdata,
    MetadataOptions: {HttpEndpoint: "enabled", HttpTokens: "required"},
    TagSpecifications: [
      {ResourceType: "instance", Tags: [
        {Key: "Name", Value: "repositorio-escolar-p08-web"},
        {Key: "proyecto", Value: "Repositorio-escolar"},
        {Key: "equipo", Value: "The-Boys"},
        {Key: "practica", Value: "08"},
        {Key: "ambiente", Value: "dev"}
      ]},
      {ResourceType: "volume", Tags: [
        {Key: "proyecto", Value: "Repositorio-escolar"},
        {Key: "equipo", Value: "The-Boys"},
        {Key: "practica", Value: "08"}
      ]}
    ]
  }' > launch-template-data.json

LAUNCH_TEMPLATE_ID=$(aws ec2 create-launch-template \
  --region "$REGION" \
  --launch-template-name "$LAUNCH_TEMPLATE_NAME" \
  --version-description "Practica 08 - servidor auto configurable" \
  --launch-template-data file://launch-template-data.json \
  --tag-specifications "$(tag_spec launch-template)" \
  --query 'LaunchTemplate.LaunchTemplateId' --output text)

TARGET_GROUP_ARN=$(aws elbv2 create-target-group \
  --region "$REGION" \
  --name "$TARGET_GROUP_NAME" \
  --protocol HTTP --port 80 \
  --vpc-id "$VPC_ID" \
  --target-type instance \
  --health-check-protocol HTTP \
  --health-check-path /health \
  --health-check-interval-seconds 10 \
  --health-check-timeout-seconds 5 \
  --healthy-threshold-count 2 \
  --unhealthy-threshold-count 2 \
  --tags Key=Name,Value="$TARGET_GROUP_NAME" Key=proyecto,Value=Repositorio-escolar Key=equipo,Value=The-Boys Key=practica,Value=08 \
  --query 'TargetGroups[0].TargetGroupArn' --output text)

aws elbv2 modify-target-group-attributes \
  --region "$REGION" \
  --target-group-arn "$TARGET_GROUP_ARN" \
  --attributes Key=deregistration_delay.timeout_seconds,Value=10

LOAD_BALANCER_ARN=$(aws elbv2 create-load-balancer \
  --region "$REGION" \
  --name "$LOAD_BALANCER_NAME" \
  --scheme internet-facing \
  --type application \
  --ip-address-type ipv4 \
  --subnets "$SUBNET_1" "$SUBNET_2" \
  --security-groups "$ALB_SG_ID" \
  --tags Key=Name,Value="$LOAD_BALANCER_NAME" Key=proyecto,Value=Repositorio-escolar Key=equipo,Value=The-Boys Key=practica,Value=08 \
  --query 'LoadBalancers[0].LoadBalancerArn' --output text)

aws elbv2 wait load-balancer-available --region "$REGION" --load-balancer-arns "$LOAD_BALANCER_ARN"

LOAD_BALANCER_DNS=$(aws elbv2 describe-load-balancers \
  --region "$REGION" \
  --load-balancer-arns "$LOAD_BALANCER_ARN" \
  --query 'LoadBalancers[0].DNSName' --output text)

LISTENER_ARN=$(aws elbv2 create-listener \
  --region "$REGION" \
  --load-balancer-arn "$LOAD_BALANCER_ARN" \
  --protocol HTTP --port 80 \
  --default-actions Type=forward,TargetGroupArn="$TARGET_GROUP_ARN" \
  --query 'Listeners[0].ListenerArn' --output text)

aws autoscaling create-auto-scaling-group \
  --region "$REGION" \
  --auto-scaling-group-name "$AUTO_SCALING_GROUP_NAME" \
  --launch-template "LaunchTemplateId=${LAUNCH_TEMPLATE_ID},Version=1" \
  --min-size 2 --max-size 4 --desired-capacity 2 \
  --vpc-zone-identifier "${SUBNET_1},${SUBNET_2}" \
  --target-group-arns "$TARGET_GROUP_ARN" \
  --health-check-type ELB \
  --health-check-grace-period 120 \
  --default-instance-warmup 120 \
  --tags \
    "Key=Name,Value=repositorio-escolar-p08-web,PropagateAtLaunch=true" \
    "Key=proyecto,Value=Repositorio-escolar,PropagateAtLaunch=true" \
    "Key=equipo,Value=The-Boys,PropagateAtLaunch=true" \
    "Key=practica,Value=08,PropagateAtLaunch=true" \
    "Key=ambiente,Value=dev,PropagateAtLaunch=true"

SCALING_POLICY_ARN=""
for attempt in {1..6}; do
  if SCALING_POLICY_ARN=$(aws autoscaling put-scaling-policy \
    --region "$REGION" \
    --auto-scaling-group-name "$AUTO_SCALING_GROUP_NAME" \
    --policy-name "$SCALING_POLICY_NAME" \
    --policy-type TargetTrackingScaling \
    --estimated-instance-warmup 120 \
    --target-tracking-configuration '{"PredefinedMetricSpecification":{"PredefinedMetricType":"ASGAverageCPUUtilization"},"TargetValue":50.0,"DisableScaleIn":false}' \
    --query PolicyARN --output text 2>policy-error.log); then
    break
  fi
  sleep $((attempt * 10))
done

if [[ -z "$SCALING_POLICY_ARN" ]]; then
  cat policy-error.log >&2
  exit 1
fi

cat > "$HOME/p08-state.env" <<EOF
export REGION='$REGION'
export VPC_ID='$VPC_ID'
export SUBNET_1='$SUBNET_1'
export SUBNET_2='$SUBNET_2'
export ALB_SG_ID='$ALB_SG_ID'
export WEB_SG_ID='$WEB_SG_ID'
export TARGET_GROUP_ARN='$TARGET_GROUP_ARN'
export LOAD_BALANCER_ARN='$LOAD_BALANCER_ARN'
export LOAD_BALANCER_DNS='$LOAD_BALANCER_DNS'
export LISTENER_ARN='$LISTENER_ARN'
export LAUNCH_TEMPLATE_ID='$LAUNCH_TEMPLATE_ID'
export AUTO_SCALING_GROUP_NAME='$AUTO_SCALING_GROUP_NAME'
export SCALING_POLICY_ARN='$SCALING_POLICY_ARN'
EOF

echo "ARQUITECTURA P08 CREADA"
echo "ALB_DNS=$LOAD_BALANCER_DNS"
echo "ASG=$AUTO_SCALING_GROUP_NAME min=2 desired=2 max=4"
echo "POLITICA_CPU_OBJETIVO=50%"
echo "HEALTH_CHECK=/health intervalo=10s sanos=2 fallos=2 gracia=120s"
