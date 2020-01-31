/*******************************************************************************
********** Cloudwatch
*******************************************************************************/

resource "aws_cloudwatch_log_group" "build" {
  name              = "/aws/codebuild/${var.service_name}"
  retention_in_days = var.log_retention
  tags = {
    Service = var.service_name
  }
}

resource "aws_cloudwatch_log_group" "build-test" {
  name              = "/aws/codebuild/${var.service_name}/test"
  retention_in_days = var.log_retention
  tags = {
    Service = var.service_name
  }
}

/*******************************************************************************
********** Build configuration
*******************************************************************************/

data "template_file" "buildspec" {
  template = file("${path.module}/buildspec.yml")

  vars = {
    repository_url = var.repository.repository_url
    region         = var.region
    environment    = "staging"
    service_name   = var.service_name
    sql_enabled    = var.sql_enabled
  }
}

resource "aws_codebuild_project" "build" {
  name          = "build-${var.service_name}"
  build_timeout = var.build_timeout
  service_role  = var.pipeline.codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  cache {
    type     = "S3"
    location = "${var.pipeline.s3_cache.bucket}/service/${var.service_name}"
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
    Service = var.service_name
  }
}


/*******************************************************************************
********** Test configuration
*******************************************************************************/

data "template_file" "buildspec-test" {
  template = file("${path.module}/buildspec-test.yml")
}

resource "aws_codebuild_project" "test" {
  name          = "test-${var.service_name}"
  build_timeout = var.build_timeout
  service_role  = var.pipeline.codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  cache {
    type     = "S3"
    location = "${var.pipeline.s3_cache.bucket}/service/${var.service_name}"
  }

  logs_config {
    cloudwatch_logs {
      group_name = aws_cloudwatch_log_group.build-test.name
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
    buildspec = data.template_file.buildspec-test.rendered
  }

  tags = {
    Service = var.service_name
  }
}

/*******************************************************************************
********** CodePipeline - Staging + Production
*******************************************************************************/

resource "aws_codepipeline" "pipeline" {
  count    = var.staging_enabled && var.production_enabled ? 1 : 0
  name     = var.service_name
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
      output_artifacts = ["imagedefinitions"]

      configuration = {
        ProjectName = aws_codebuild_project.build.name
      }
    }

    action {
      name            = "Test"
      category        = "Test"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["source"]

      configuration = {
        ProjectName = aws_codebuild_project.test.name
      }
    }
  }

  stage {
    name = "Staging"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeployToECS"
      input_artifacts = ["imagedefinitions"]
      version         = "1"

      configuration = {
        ApplicationName                = "staging-${var.service_name}"
        DeploymentGroupName            = "staging-${var.service_name}"
        AppSpecTemplateArtifact        = "imagedefinitions"
        AppSpecTemplatePath            = "appspec.yml"
        TaskDefinitionTemplateArtifact = "imagedefinitions"
        TaskDefinitionTemplatePath     = "staging-taskdef.json"
        Image1ArtifactName             = "imagedefinitions"
        Image1ContainerName            = "IMAGE1_NAME"
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
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeployToECS"
      input_artifacts = ["imagedefinitions"]
      version         = "1"

      configuration = {
        ApplicationName                = "production-${var.service_name}"
        DeploymentGroupName            = "production-${var.service_name}"
        AppSpecTemplateArtifact        = "imagedefinitions"
        AppSpecTemplatePath            = "appspec.yml"
        TaskDefinitionTemplateArtifact = "imagedefinitions"
        TaskDefinitionTemplatePath     = "production-taskdef.json"
        Image1ArtifactName             = "imagedefinitions"
        Image1ContainerName            = "IMAGE1_NAME"
      }
    }
  }
  depends_on = [var.production_deployment_strategy, var.staging_deployment_strategy]

  lifecycle {
    ignore_changes = [stage[0].action[0].configuration]
  }

  tags = {
    Service = var.service_name
  }
}


/*******************************************************************************
********** CodePipeline - Staging only
*******************************************************************************/

resource "aws_codepipeline" "pipeline_staging_only" {
  count    = var.staging_enabled == true && var.production_enabled == false ? 1 : 0
  name     = var.service_name
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
      output_artifacts = ["imagedefinitions"]

      configuration = {
        ProjectName = aws_codebuild_project.build.name
      }
    }

    action {
      name            = "Test"
      category        = "Test"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["source"]

      configuration = {
        ProjectName = aws_codebuild_project.test.name
      }
    }
  }

  stage {
    name = "Staging"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeployToECS"
      input_artifacts = ["imagedefinitions"]
      version         = "1"

      configuration = {
        ApplicationName                = "staging-${var.service_name}"
        DeploymentGroupName            = "staging-${var.service_name}"
        AppSpecTemplateArtifact        = "imagedefinitions"
        AppSpecTemplatePath            = "appspec.yml"
        TaskDefinitionTemplateArtifact = "imagedefinitions"
        TaskDefinitionTemplatePath     = "staging-taskdef.json"
        Image1ArtifactName             = "imagedefinitions"
        Image1ContainerName            = "IMAGE1_NAME"
      }
    }
  }

  depends_on = [var.staging_deployment_strategy]

  lifecycle {
    ignore_changes = [stage[0].action[0].configuration]
  }

  tags = {
    Service = var.service_name
  }
}

/*******************************************************************************
********** CodePipeline - No staging only production => Forbidden
*******************************************************************************/

resource "aws_codepipeline" "pipeline_prod_only" {
  count    = var.production_enabled == true && var.staging_enabled == false ? 1 : 0
  name     = var.service_name
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
    name = "STAGING_ENV_DISABLED"

    action {
      name     = "THATS_OK"
      category = "Approval"
      owner    = "AWS"
      provider = "Manual"
      version  = "1"
    }
  }

  stage {
    name = "PRODUCTION_ENV_ENABLED"

    action {
      name     = "FORBIDDEN_WITHOUT_STAGING"
      category = "Approval"
      owner    = "AWS"
      provider = "Manual"
      version  = "1"
    }
  }

  lifecycle {
    ignore_changes = [stage[0].action[0].configuration]
  }

  tags = {
    Service = var.service_name
  }

}

/*******************************************************************************
********** CodePipeline - No staging No production => Disabled
*******************************************************************************/

resource "aws_codepipeline" "pipeline_disabled" {
  count    = var.production_enabled == false && var.staging_enabled == false ? 1 : 0
  name     = var.service_name
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
    name = "STAGING_ENV_DISABLED"

    action {
      name     = "CHECK_TERRAFORM"
      category = "Approval"
      owner    = "AWS"
      provider = "Manual"
      version  = "1"
    }
  }

  stage {
    name = "PRODUCTION_ENV_DISABLED"

    action {
      name     = "CHECK_TERRAFORM"
      category = "Approval"
      owner    = "AWS"
      provider = "Manual"
      version  = "1"
    }
  }

  lifecycle {
    ignore_changes = [stage[0].action[0].configuration]
  }

  tags = {
    Service = var.service_name
  }

}