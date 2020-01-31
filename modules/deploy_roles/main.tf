
locals {
  iam_name = "ecs-codedeploy"
}

# ECS AWS CodeDeploy IAM Role
#
# https://docs.aws.amazon.com/ja_jp/AmazonECS/latest/developerguide/codedeploy_IAM_role.html

# https://www.terraform.io/docs/providers/aws/r/iam_role.html
resource "aws_iam_role" "default" {
  name               = "${var.environment}_${local.iam_name}"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
  tags = {
    Name = "${var.environment}_${local.iam_name}"
  }
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codedeploy.amazonaws.com", "s3.amazonaws.com"]
    }
  }
}

# https://www.terraform.io/docs/providers/aws/r/iam_policy.html
resource "aws_iam_policy" "default" {
  name   = "${var.environment}_${local.iam_name}"
  policy = data.aws_iam_policy_document.policy.json
}

data "aws_iam_policy_document" "policy" {
  # If the tasks in your Amazon ECS service using the blue/green deployment type require the use of
  # the task execution role or a task role override, then you must add the iam:PassRole permission
  # for each task execution role or task role override to the AWS CodeDeploy IAM role as an inline policy.
  statement {
    effect = "Allow"

    actions = [
      "iam:PassRole",
    ]

    resources = ["*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "ecs:DescribeServices",
      "ecs:CreateTaskSet",
      "ecs:UpdateServicePrimaryTaskSet",
      "ecs:DeleteTaskSet",
      "cloudwatch:DescribeAlarms",
    ]

    resources = ["*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "sns:Publish",
    ]

    resources = ["arn:aws:sns:*:*:CodeDeployTopic_*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:ModifyListener",
      "elasticloadbalancing:DescribeRules",
      "elasticloadbalancing:ModifyRule",
    ]

    resources = ["*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "lambda:InvokeFunction",
    ]

    resources = ["arn:aws:lambda:*:*:function:CodeDeployHook_*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:*"
    ]

    resources = ["*"]
  }

  /**** Lambda *****/
  statement {
    actions = [
      "cloudwatch:DescribeAlarms",
      "lambda:UpdateAlias",
      "lambda:GetAlias",
      "lambda:GetProvisionedConcurrencyConfig",
      "sns:Publish"
    ]
    resources = ["*"]
    effect    = "Allow"
  }
  statement {
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion"
    ]
    resources = ["arn:aws:s3:::*/CodeDeploy/*"]
    effect    = "Allow"
  }
  statement {
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion"
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "s3:ExistingObjectTag/UseWithCodeDeploy"
      values   = ["true"]
    }
    effect = "Allow"
  }
  statement {
    actions = [
      "lambda:InvokeFunction"
    ]
    resources = ["arn:aws:lambda:*:*:function:CodeDeployHook_*"]
    effect    = "Allow"
  }
}

# https://www.terraform.io/docs/providers/aws/r/iam_role_policy_attachment.html
resource "aws_iam_role_policy_attachment" "default" {
  role       = aws_iam_role.default.name
  policy_arn = aws_iam_policy.default.arn
}
