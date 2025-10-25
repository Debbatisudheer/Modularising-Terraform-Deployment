output "alb_dns_address" {
  description = "The DNS name of the ALB"
  value       = aws_lb.alb.dns_name
}

output "address" {
  value = aws_lb.alb.dns_name
}
