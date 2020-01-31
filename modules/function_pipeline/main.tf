locals {
  terraform_version = "0.12.20"
}

/*******************************************************************************
********** Cloudwatch
*******************************************************************************/

resource "aws_cloudwatch_log_group" "build" {
  name              = "/aws/codebuild/${var.function_name}"
  retention_in_days = var.log_retention
  tags = {
    Function = var.function_name
  }
}

resource "aws_cloudwatch_log_group" "deploy-staging" {
  name              = "/aws/codebuild/${var.function_name}/deploy/staging"
  retention_in_days = var.log_retention
  tags = {
    Function    = var.function_name
    Environment = "staging"
  }
}

resource "aws_cloudwatch_log_group" "deploy-production" {
  name              = "/aws/codebuild/${var.function_name}/deploy/production"
  retention_in_days = var.log_retention
  tags = {
    Function    = var.function_name
    Environment = "production"
  }
}

/*******************************************************************************
********** Buildspec - build
*******************************************************************************/

data "template_file" "buildspec" {
  template = file("${path.module}/buildspec.yml")

  vars = {
    repository_url = var.git_repository
    region         = var.region
    environment    = "staging"
    function_name  = var.function_name
  }
}

resource "aws_codebuild_project" "build" {
  name          = "build-${var.function_name}"
  build_timeout = var.build_timeout
  service_role  = var.pipeline.codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  cache {
    type     = "S3"
    location = "${var.pipeline.s3_cache.bucket}/lambda/${var.function_name}"
  }

  logs_config {
    cloudwatch_logs {
      group_name = aws_cloudwatch_log_group.build.name
    }
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    // https://docs.aws.amazon.com/codebuild/latest/userguide/build-env-ref-available.html
    image           = "aws/codebuild/amazonlinux2-x86_64-standard:2.0-19.11.26"
    type            = "LINUX_CONTAINER"
    privileged_mode = true
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = data.template_file.buildspec.rendered
  }

  tags = {
    Service = var.function_name
  }
}

/*******************************************************************************
********** Buildspec - staging
*******************************************************************************/

data "template_file" "buildspec-deploy-staging" {
  template = file("${path.module}/buildspec-deploy.yml")

  vars = {
    environment       = "staging"
    function_name     = var.function_name
    alb_listener_arn  = var.staging_alb_listener.arn
    terraform_version = local.terraform_version
  }
}

resource "aws_codebuild_project" "deploy-staging" {
  name          = "build-deploy-staging-${var.function_name}"
  build_timeout = var.build_timeout
  service_role  = var.pipeline.codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  cache {
    type     = "S3"
    location = "${var.pipeline.s3_cache.bucket}/lambda/${var.function_name}"
  }

  logs_config {
    cloudwatch_logs {
      group_name = aws_cloudwatch_log_group.deploy-staging.name
    }
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/amazonlinux2-x86_64-standard:2.0-19.11.26"
    type            = "LINUX_CONTAINER"
    privileged_mode = true
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = data.template_file.buildspec-deploy-staging.rendered
  }

  tags = {
    Service = var.function_name
  }
}

/*******************************************************************************
********** Buildspec - production
*******************************************************************************/

data "template_file" "buildspec-deploy-production" {
  template = file("${path.module}/buildspec-deploy.yml")

  vars = {
    environment       = "production"
    function_name     = var.function_name
    alb_listener_arn  = var.production_alb_listener.arn
    terraform_version = local.terraform_version
  }
}

resource "aws_codebuild_project" "deploy-production" {
  name          = "build-deploy-production-${var.function_name}"
  build_timeout = var.build_timeout
  service_role  = var.pipeline.codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  cache {
    type     = "S3"
    location = "${var.pipeline.s3_cache.bucket}/lambda/${var.function_name}"
  }

  logs_config {
    cloudwatch_logs {
      group_name = aws_cloudwatch_log_group.deploy-production.name
    }
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/amazonlinux2-x86_64-standard:2.0-19.11.26"
    type            = "LINUX_CONTAINER"
    privileged_mode = true
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = data.template_file.buildspec-deploy-production.rendered
  }

  tags = {
    Service = var.function_name
  }
}

/*******************************************************************************
********** CodePipeline - staging
*******************************************************************************/

resource "aws_codepipeline" "pipeline_staging_only" {
  count    = var.staging_enabled == true && var.production_enabled == false ? 1 : 0
  name     = var.function_name
  role_arn = var.pipeline.codepipeline_role.arn

  artifact_store {
    location = var.pipeline.s3_source.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = "GitHub"
      version          = "1"
      output_artifacts = ["source"]

      configuration = {
        Owner                = var.git_owner
        Repo                 = var.git_repository
        Branch               = var.branch
        PollForSourceChanges = true
        OAuthToken           = var.github_token
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["source"]
      output_artifacts = ["payload"]

      configuration = {
        ProjectName = aws_codebuild_project.build.name
      }
    }
  }

  stage {
    name = "Staging"

    action {
      name            = "Build"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["payload"]

      configuration = {
        ProjectName = aws_codebuild_project.deploy-staging.name
      }
    }
  }

  lifecycle {
    ignore_changes = [stage[0].action[0].configuration]
  }

}

/*******************************************************************************
********** CodePipeline - staging + production
*******************************************************************************/

resource "aws_codepipeline" "pipeline" {
  count    = var.staging_enabled && var.production_enabled ? 1 : 0
  name     = var.function_name
  role_arn = var.pipeline.codepipeline_role.arn

  artifact_store {
    location = var.pipeline.s3_source.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = "GitHub"
      version          = "1"
      output_artifacts = ["source"]

      configuration = {
        Owner                = var.git_owner
        Repo                 = var.git_repository
        Branch               = var.branch
        PollForSourceChanges = true
        OAuthToken           = var.github_token
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["source"]
      output_artifacts = ["payload"]

      configuration = {
        ProjectName = aws_codebuild_project.build.name
      }
    }
  }

  stage {
    name = "Staging"

    action {
      name            = "Build"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["payload"]

      configuration = {
        ProjectName = aws_codebuild_project.deploy-staging.name
      }
    }
  }

  stage {
    name = "Approval"

    action {
      name     = "Approval"
      category = "Approval"
      owner    = "AWS"
      provider = "Manual"
      version  = "1"
    }
  }

  stage {
    name = "Production"

    action {
      name            = "Build"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["payload"]

      configuration = {
        ProjectName = aws_codebuild_project.deploy-production.name
      }
    }
  }

  lifecycle {
    ignore_changes = [stage[0].action[0].configuration]
  }

}


