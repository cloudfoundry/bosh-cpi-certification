variable "access_key" {}
variable "secret_key" {}
variable "region" {}
variable "env_name" {}
variable "public_key" {}

provider "aws" {
  access_key = var.access_key
  secret_key = var.secret_key
  region     = var.region
}

data "aws_availability_zones" "available" {}

# Create a VPC to launch our instances into
resource "aws_vpc" "default" {
  assign_generated_ipv6_cidr_block = true
  cidr_block                       = "10.0.0.0/16"
  tags = {
    Name = "${var.env_name}"
  }
}

# Create an internet gateway to give our subnet access to the outside world
resource "aws_internet_gateway" "default" {
  vpc_id = aws_vpc.default.id
  tags = {
    Name = "${var.env_name}"
  }
}

resource "aws_route_table" "default" {
  vpc_id = aws_vpc.default.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.default.id
  }

  tags = {
    Name = "${var.env_name}"
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.default.id
  route_table_id = aws_route_table.default.id
}

resource "aws_subnet" "default" {
  vpc_id            = aws_vpc.default.id
  cidr_block        = cidrsubnet(aws_vpc.default.cidr_block, 8, 0)
  ipv6_cidr_block   = cidrsubnet(aws_vpc.default.ipv6_cidr_block, 8, 0)
  depends_on        = ["aws_internet_gateway.default"]
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "${var.env_name}"
  }

  map_public_ip_on_launch = true
}

resource "aws_route_table_association" "aws_resources" {
  subnet_id      = aws_subnet.aws_resources.id
  route_table_id = aws_route_table.default.id
}

resource "aws_subnet" "aws_resources" {
  vpc_id            = aws_vpc.default.id
  cidr_block        = cidrsubnet(aws_vpc.default.cidr_block, 8, 1)
  ipv6_cidr_block   = cidrsubnet(aws_vpc.default.ipv6_cidr_block, 8, 1)
  depends_on        = ["aws_internet_gateway.default"]
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "${var.env_name}-aws-resources"
  }
}

resource "aws_network_acl" "allow_all" {
  vpc_id     = aws_vpc.default.id
  subnet_ids = ["${aws_subnet.default.id}"]
  egress {
    protocol   = "-1"
    rule_no    = 2
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  ingress {
    protocol   = "-1"
    rule_no    = 1
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name = "${var.env_name}"
  }
}

resource "aws_security_group" "allow_all" {
  vpc_id = aws_vpc.default.id
  name   = "allow_all-${var.env_name}"
  # description = "Allow all inbound and outgoing traffic"
  description = "Allow local and concourse traffic"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.env_name}"
  }
}

resource "aws_eip" "director" {
  vpc = true
}

resource "aws_eip" "bats" {
  vpc = true
}

# Create a new classic load balancer
resource "aws_elb" "e2e" {
  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  subnets = ["${aws_subnet.aws_resources.id}"]

  tags = {
    Name = "${var.env_name}-e2e"
  }
}

resource "aws_iam_role_policy" "e2e" {
  name   = "${var.env_name}-policy"
  role   = aws_iam_role.e2e.id
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Action": [
      "ec2:AssociateAddress",
      "ec2:AttachVolume",
      "ec2:CreateVolume",
      "ec2:DeleteSnapshot",
      "ec2:DeleteVolume",
      "ec2:Describe*",
      "ec2:DetachVolume",
      "ec2:CreateSnapshot",
      "ec2:CreateTags",
      "ec2:RunInstances",
      "ec2:TerminateInstances",
      "ec2:RequestSpotInstances",
      "ec2:CancelSpotInstanceRequests",
      "ec2:DeregisterImage",
      "ec2:DescribeImages",
      "ec2:RegisterImage"
    ],
    "Effect": "Allow",
		"Resource": "*"
  },
  {
    "Effect": "Allow",
    "Action": "elasticloadbalancing:*",
		"Resource": "*"
  }]
}
EOF
}

resource "aws_iam_instance_profile" "e2e" {
  role = aws_iam_role.e2e.name
}

resource "aws_iam_role" "e2e" {
  name_prefix        = var.env_name
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_key_pair" "director" {
  key_name   = var.env_name
  public_key = var.public_key
}

resource "aws_kms_key" "key" {
  description             = "${var.env_name}-kms-key"
  deletion_window_in_days = 7
}

output "vpc_id" {
  value = aws_vpc.default.id
}
output "region" {
  value = var.region
}

# Used by bats
output "default_key_name" {
  value = aws_key_pair.director.key_name
}
output "default_security_groups" {
  value = ["${aws_security_group.allow_all.name}"]
}
output "external_ip" {
  value = aws_eip.director.public_ip
}
output "az" {
  value = aws_subnet.default.availability_zone
}
output "subnet_id" {
  value = aws_subnet.default.id
}
output "internal_cidr" {
  value = aws_vpc.default.cidr_block
}
output "internal_gw" {
  value = cidrhost(aws_vpc.default.cidr_block, 1)
}
output "dns_recursor_ip" {
  value = cidrhost(aws_vpc.default.cidr_block, 2)
}
output "internal_ip" {
  value = cidrhost(aws_vpc.default.cidr_block, 6)
}
output "reserved_range" {
  value = "${cidrhost(aws_vpc.default.cidr_block, 2)}-${cidrhost(aws_vpc.default.cidr_block, 9)}"
}
output "static_range" {
  value = "${cidrhost(aws_vpc.default.cidr_block, 10)}-${cidrhost(aws_vpc.default.cidr_block, 30)}"
}
output "bats_eip" {
  value = aws_eip.bats.public_ip
}
output "network_static_ip_1" {
  value = cidrhost(aws_vpc.default.cidr_block, 29)
}
output "network_static_ip_2" {
  value = cidrhost(aws_vpc.default.cidr_block, 30)
}

# Used by end-2-end tests
output "iam_instance_profile" {
  value = aws_iam_instance_profile.e2e.name
}
output "e2e_elb_name" {
  value = aws_elb.e2e.id
}
output "aws_kms_key_arn" {
  value = aws_kms_key.key.arn
}
