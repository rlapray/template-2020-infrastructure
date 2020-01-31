output "codebuild_role" {
  value = "${aws_iam_role.codebuild_role}"
}

output "codepipeline_role" {
  value = "${aws_iam_role.codepipeline_role}"
}

output "s3_source" {
  value = "${aws_s3_bucket.source}"
}

output "s3_cache" {
  value = "${aws_s3_bucket.cache}"
}