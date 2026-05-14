# modules/alb/outputs.tf

output "alb_dns_name" {
  value       = aws_lb.this.dns_name
  description = "ALB public DNS name"
}

output "alb_arn" {
  value       = aws_lb.this.arn
  description = "ALB ARN"
}

output "target_group_arn" {
  value       = aws_lb_target_group.this.arn
  description = "Target group ARN"
}
