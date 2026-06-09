# Configure the AWS provider for the target region
provider "aws" {
  region = "us-east-1"
}

# Create a VPC for the demo infrastructure
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = "tf-alb-demo"
  }
}

# Attach an Internet Gateway so resources in the VPC can access the internet
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "tf-alb-demo-igw"
  }
}

# Public subnet 1 for EC2 instances and the ALB
resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_1_cidr
  map_public_ip_on_launch = true
  availability_zone = "${var.aws_region}a"

  tags = {
    Name = "public_subnet_1"
  }
}

# Route table for subnet 1 with internet access
resource "aws_route_table" "public_rtb_1" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

# Associate the route table with public subnet 1
resource "aws_route_table_association" "public_subnet_1_association" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_rtb_1.id
}

# Public subnet 2 for availability and ALB backends
resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_2_cidr
  map_public_ip_on_launch = true
  availability_zone = "${var.aws_region}b"

  tags = {
    Name = "public_subnet_2"
  }
}

# Route table for subnet 2 with internet access
resource "aws_route_table" "public_rtb_2" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

# Associate the route table with public subnet 2
resource "aws_route_table_association" "public_subnet_2_association" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_rtb_2.id
}

# Security group for EC2 instances allowing SSH and HTTP
resource "aws_security_group" "web_sg_allow_ssh_http" {
  name        = "allow-ssh-http"
  description = "Allow SSH and HTTP inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "allow-ssh-http"
  }
}

# Allow SSH from anywhere for management access
resource "aws_vpc_security_group_ingress_rule" "allow_ssh" {
  security_group_id = aws_security_group.web_sg_allow_ssh_http.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

# Allow HTTP from anywhere to the EC2 instances
resource "aws_vpc_security_group_ingress_rule" "allow_http" {
  security_group_id            = aws_security_group.web_sg_allow_ssh_http.id
  referenced_security_group_id = aws_security_group.alb_sg_allow_http.id
  from_port   = 80
  ip_protocol = "tcp"
  to_port     = 80
}

# Allow all outbound traffic from the EC2 security group
resource "aws_vpc_security_group_egress_rule" "allow_all_outbound" {
  security_group_id = aws_security_group.web_sg_allow_ssh_http.id
  description       = "Allow all outbound traffic"

  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"
}

# SSH key pair used by EC2 instances
resource "aws_key_pair" "my_ec2_key" {
  key_name   = "shyam-ec2-key"
  public_key = file("~/.ssh/shyamdevops_key.pub")
}

# First EC2 instance in public subnet 1
resource "aws_instance" "demo-server_1" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.my_ec2_key.key_name
  vpc_security_group_ids = [aws_security_group.web_sg_allow_ssh_http.id]
  subnet_id              = aws_subnet.public_subnet_1.id

  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo yum install httpd -y
              sudo systemctl start httpd
              sudo systemctl enable httpd
              echo "<h1>Welcome to shyamdevops.online - Server 1</h1>" | sudo tee /var/www/html/index.html
              EOF
  tags = {
    name = "terraform-demo-first-ec2"
  }
}

# Second EC2 instance in public subnet 2
resource "aws_instance" "demo-server_2" {
  ami                    = "ami-00e801948462f718a"
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.my_ec2_key.key_name
  vpc_security_group_ids = [aws_security_group.web_sg_allow_ssh_http.id]
  subnet_id              = aws_subnet.public_subnet_2.id

  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo yum install httpd -y
              sudo systemctl start httpd
              sudo systemctl enable httpd
              echo "<h1>Welcome to shyamdevops.online - Server 2</h1>" | sudo tee /var/www/html/index.html
              EOF

  tags = {
    name = "terraform-demo-first-ec2"
  }
}

# Security group for the Application Load Balancer allowing HTTP traffic
resource "aws_security_group" "alb_sg_allow_http" {
  name        = "allow-http"
  description = "Allow HTTP inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "allow-http"
  }
}

# Allow HTTP from anywhere to the ALB
resource "aws_vpc_security_group_ingress_rule" "allow_http_lb" {
  security_group_id = aws_security_group.alb_sg_allow_http.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

# Allow HTTPs from anywhere to the ALB
resource "aws_vpc_security_group_ingress_rule" "allow_https_lb" {
  security_group_id = aws_security_group.alb_sg_allow_http.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

# Allow outbound traffic from the ALB security group
resource "aws_vpc_security_group_egress_rule" "allow_alb_outbound" {
  security_group_id = aws_security_group.alb_sg_allow_http.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# Application Load Balancer definition
resource "aws_lb" "test" {
  name               = "tf-demo-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg_allow_http.id]
  subnets = [
    aws_subnet.public_subnet_1.id,
    aws_subnet.public_subnet_2.id
  ]
}

# Target group for the ALB to forward HTTP requests to EC2 instances
resource "aws_lb_target_group" "tf-demo-tg" {
  name        = "tf-demo-tg"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.main.id
}

# Attach the first EC2 instance to the target group
resource "aws_lb_target_group_attachment" "tf-demo-tg-attachment_1" {
  target_group_arn = aws_lb_target_group.tf-demo-tg.arn
  target_id        = aws_instance.demo-server_1.id
  port             = 80
}

# Attach the second EC2 instance to the target group
resource "aws_lb_target_group_attachment" "tf-demo-tg-attachment_2" {
  target_group_arn = aws_lb_target_group.tf-demo-tg.arn
  target_id        = aws_instance.demo-server_2.id
  port             = 80
}

# Use an existing ACM certificate for HTTPS listener
data "aws_acm_certificate" "existing_cert" {
  domain   = "shyamdevops.online"
  statuses = ["ISSUED"] # Only find it if it's already active
}

# HTTPS listener for the ALB using the ACM certificate
resource "aws_lb_listener" "front_end_https" {
  load_balancer_arn = aws_lb.test.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = data.aws_acm_certificate.existing_cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tf-demo-tg.arn
  }
}

# Redirect HTTP traffic to HTTPS
resource "aws_lb_listener" "redirect_http_to_https" {
  load_balancer_arn = aws_lb.test.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# Route53 hosted zone for the domain
resource "aws_route53_zone" "primary" {
  name = "shyamdevops.online"
}

# A record for the root domain pointing to the ALB
resource "aws_route53_record" "root_domain" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = "shyamdevops.online"
  type    = "A"
  alias {
    name                   = aws_lb.test.dns_name
    zone_id                = aws_lb.test.zone_id
    evaluate_target_health = true
  }
}

# Subdomain record placeholder for future use
resource "aws_route53_record" "sub_domain" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = "app.shyamdevops.online"
  type    = "A"
  alias {
    name                   = aws_lb.test.dns_name
    zone_id                = aws_lb.test.zone_id
    evaluate_target_health = true
  }
}

