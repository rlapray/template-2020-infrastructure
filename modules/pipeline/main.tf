resource "aws_s3_bucket" "source" {
  bucket        = var.source_bucket_name
  acl           = "private"
  force_destroy = true

  lifecycle_rule {
    enabled = true

    noncurrent_version_transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    noncurrent_version_expiration {
      days = 90
    }
  }
}

resource "aws_s3_bucket" "cache" {
  bucket        = var.cache_bucket_name
  acl           = "private"
  force_destroy = true

  lifecycle_rule {
    enabled = true

    noncurrent_version_expiration {
      days = 30
    }
  }
}

resource "aws_s3_bucket" "terraform" {
  bucket        = var.terraform_bucket_name
  acl           = "private"
  force_destroy = true

  versioning {
    enabled = true
  }
}

resource "aws_iam_role" "codepipeline_role" {
  name               = "codepipeline_role"
  assume_role_policy = file("${path.module}/policies/codepipeline_role.json")
}

/* policies */
data "template_file" "codepipeline_policy" {
  template = file("${path.module}/policies/codepipeline.json")

  vars = {
    s3_source    = aws_s3_bucket.source.arn
    s3_cache     = aws_s3_bucket.cache.arn
    s3_terraform = aws_s3_bucket.terraform.arn
  }
}

resource "aws_iam_role_policy" "codepipeline_policy" {
  name   = "codepipeline_policy"
  role   = aws_iam_role.codepipeline_role.id
  policy = data.template_file.codepipeline_policy.rendered
}

/*
/* CodeBuild
*/
resource "aws_iam_role" "codebuild_role" {
  name               = "codebuild_role"
  assume_role_policy = file("${path.module}/policies/codebuild_role.json")
}

data "template_file" "codebuild_policy" {
  template = file("${path.module}/policies/codebuild_policy.json")

  vars = {
    s3_source    = aws_s3_bucket.source.arn
    s3_cache     = aws_s3_bucket.cache.arn
    s3_terraform = aws_s3_bucket.terraform.arn
  }
}

resource "aws_iam_role_policy" "codebuild_policy" {
  name   = "codebuild_policy"
  role   = aws_iam_role.codebuild_role.id
  policy = data.template_file.codebuild_policy.rendered
}