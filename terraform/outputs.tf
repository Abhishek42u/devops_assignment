output "alb_dns_name" {
  description = "Open this URL in your browser to access the app"
  value       = "http://${aws_lb.main.dns_name}"
}

output "cloudfront_url" {
  description = "CloudFront URL for static assets"
  value       = "https://${aws_cloudfront_distribution.main.domain_name}"
}

output "s3_bucket_name" {
  description = "S3 bucket name for static content — use this in GitHub Actions secret S3_BUCKET_NAME"
  value       = aws_s3_bucket.static.id
}

output "asg_name" {
  description = "Auto Scaling Group name — used in GitHub Actions deploy workflow"
  value       = aws_autoscaling_group.app.name
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "sns_topic_arn" {
  description = "SNS topic ARN — check your email and confirm the subscription to receive alerts"
  value       = aws_sns_topic.alerts.arn
}
