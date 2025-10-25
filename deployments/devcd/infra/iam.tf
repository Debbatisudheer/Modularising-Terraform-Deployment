resource "aws_iam_role" "alb_ecs_instance_role" {
  name = "${var.environment}-alb-ecs-instance-role"

  lifecycle {
    create_before_destroy = true
  }

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Effect": "Allow",
        "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
        }
      }
    ]
}
EOF
}

resource "aws_iam_policy" "alb_ec2_policy" {
  name = "${var.environment}-alb-ec2-policy"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "ecs:Describe*",
          "ec2:Describe*",
          "cloudwatch:*",
          "s3:*",
          "ecr:*",
          "lambda:*",
          "kinesis:*"
        ],
        "Resource": "*"
      }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "alb_ecs_policy_attach" {
  role = aws_iam_role.alb_ecs_instance_role.name

  lifecycle {
    create_before_destroy = true
  }

  policy_arn = aws_iam_policy.alb_ec2_policy.arn
}

resource "aws_iam_instance_profile" "alb_ecs_instance_profile" {
  name = "${var.environment}-alb-ecs-instance-profile"

  lifecycle {
    create_before_destroy = true
  }

  role = aws_iam_role.alb_ecs_instance_role.name
}

