output "alb_dns_name" {
  description = "The DNS name of the Application Load Balancer"
  value       = aws_lb.test.dns_name
}

output "route_53_name_server" {
  description = "The name server for the Route 53 hosted zone"
  value       = aws_route53_zone.primary.name_servers
}