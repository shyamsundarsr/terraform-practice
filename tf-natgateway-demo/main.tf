provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "test-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "test-vpc"
  }
}

resource "aws_internet_gateway" "test-igw" {
  vpc_id = aws_vpc.test-vpc.id
  tags = {
    Name = "test-igw"
  }
}

resource "aws_subnet" "pubsubnet" {
  vpc_id = aws_vpc.test-vpc.id
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = true
  tags = {
    Name = "pubsubnet"
  }
}

resource "aws_subnet" "privsubnet" {
  vpc_id = aws_vpc.test-vpc.id
  cidr_block = "10.0.2.0/24"
  tags = {
    Name = "privsubnet"
  }
}

resource "aws_route_table" "test-pub-rt" {
  vpc_id = aws_vpc.test-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.test-igw.id
  }
  tags = {
    Name = "test-pub-rt"
  }
}

resource "aws_route_table" "test-private-rt" {
  vpc_id = aws_vpc.test-vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.test-natgw.id
  }
  tags = {
    Name = "test-private-rt"
  }
}

resource "aws_route_table_association" "test-priv-aws_route_table_association" {
  subnet_id = aws_subnet.privsubnet.id
  route_table_id = aws_route_table.test-private-rt.id
}

resource "aws_route_table_association" "test-pub-aws_route_table_association" {
  subnet_id = aws_subnet.pubsubnet.id
  route_table_id = aws_route_table.test-pub-rt.id
}

resource "aws_nat_gateway" "test-natgw" {
  allocation_id = aws_eip.test-eip.id
  subnet_id = aws_subnet.pubsubnet.id
  tags = {
    Name = "test-natgw"
  }
  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.test-igw]
}

resource "aws_eip" "test-eip" {
  domain = "vpc"
  tags = {
    Name = "nat-eip"
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
  filter {
    name = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["137112412989"] # Amazon
}

resource "aws_instance" "terraform-ec2" {
  ami = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  associate_public_ip_address = true
  subnet_id = aws_subnet.pubsubnet.id
  tags = {
    Name = "HelloWorld"
  }
}

resource "aws_instance" "terraform-ec2-1" {
  ami = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  subnet_id = aws_subnet.privsubnet.id
  tags = {
    Name = "HelloWorld1"
  }
}
