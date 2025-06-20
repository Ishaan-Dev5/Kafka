provider "aws" {
  region = "ap-south-1"
}

resource "aws_vpc" "main" {
  cidr_block       = var.vpc_cidr
  instance_tenancy = "default"

  tags = {
    Name = "KAFKA"
  }
}

resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.0.0/25"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet-1"
  }

}

resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.0.128/25"
  availability_zone       = "ap-south-1b"
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet-2"
  }
}

resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.8.0/21"
  availability_zone = "ap-south-1a"

  tags = {
    Name = "private-subnet-1"
  }
}


resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.16.0/21"
  availability_zone = "ap-south-1b"

  tags = {
    Name = "private-subnet-2"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "kafka_igw"
  }
}


resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "NAT" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet_1.id

  tags = {
    Name = "kafka_NAT"
  }

  depends_on = [aws_internet_gateway.gw]
}

resource "aws_route_table" "public_RT" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }



  tags = {
    Name = "Public_RT"
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_RT.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_RT.id
}

resource "aws_route_table" "private_RT" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.NAT.id
  }



  tags = {
    Name = "Private_RT"
  }
}

resource "aws_route_table_association" "c" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_RT.id
}

resource "aws_route_table_association" "d" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_RT.id
}

# Private NACL
resource "aws_network_acl" "private_nacl" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "private-nacl"
  }
}

resource "aws_network_acl_rule" "private_inbound_kafka" {
  network_acl_id = aws_network_acl.private_nacl.id
  rule_number    = 100
  egress         = false
  protocol       = "6"
  rule_action    = "allow"
  cidr_block     = "10.0.0.0/16"
  from_port      = 9092
  to_port        = 9093
}

resource "aws_network_acl_rule" "private_inbound_ssh" {
  network_acl_id = aws_network_acl.private_nacl.id
  rule_number    = 110
  egress         = false
  protocol       = "6"
  rule_action    = "allow"
  cidr_block     = "10.0.0.0/16"
  from_port      = 22
  to_port        = 22
}

resource "aws_network_acl_rule" "private_inbound_ephemeral" {
  network_acl_id = aws_network_acl.private_nacl.id
  rule_number    = 120
  egress         = false
  protocol       = "6"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl_rule" "private_inbound_nat_response" {
  network_acl_id = aws_network_acl.private_nacl.id
  rule_number    = 130
  egress         = false
  protocol       = "6" # TCP
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 32768
  to_port        = 65535
}


resource "aws_network_acl_rule" "private_outbound_all" {
  network_acl_id = aws_network_acl.private_nacl.id
  rule_number    = 100
  egress         = true
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
}

# Associate private NACL
resource "aws_network_acl_association" "assoc_private_1" {
  subnet_id      = aws_subnet.private_subnet_1.id
  network_acl_id = aws_network_acl.private_nacl.id
}

resource "aws_network_acl_association" "assoc_private_2" {
  subnet_id      = aws_subnet.private_subnet_2.id
  network_acl_id = aws_network_acl.private_nacl.id
}


resource "aws_security_group" "public_sg" {
  name   = "public-sg"
  vpc_id = aws_vpc.main.id


  ingress {

    from_port   = 80
    to_port     = 80
    protocol    = "tcp"         # -1 means all protocols
    cidr_blocks = ["0.0.0.0/0"] # From anywhere
  }

  ingress {

    from_port   = 22
    to_port     = 22
    protocol    = "tcp"         # -1 means all protocols
    cidr_blocks = ["0.0.0.0/0"] # From anywhere
  }
  egress {

    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "public-sg"
  }
}

resource "aws_security_group" "private_sg" {
  name = "private-sg"

  vpc_id = aws_vpc.main.id

  ingress {

    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.public_sg.id]
  }

  ingress {

    from_port       = 9092
    to_port         = 9093
    protocol        = "tcp"
    security_groups = [aws_security_group.public_sg.id]
  }
  egress {

    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "private-sg"
  }
}


resource "aws_instance" "instance" {
  ami                    = "ami-021a584b49225376d" # Replace with actual AMI ID for your region
  instance_type          = "t3.medium"
  subnet_id              = aws_subnet.public_subnet_1.id     # Your subnet ID
  key_name               = "slave"                           # Optional: your EC2 key pair
  vpc_security_group_ids = [aws_security_group.public_sg.id] # Security group ID

  associate_public_ip_address = true
  tags = {
    Name = "bastionhost"
  }
}

resource "aws_instance" "private_instance_1" {
  ami                    = "ami-021a584b49225376d" # Replace with your AMI
  instance_type          = "t3.medium"
  subnet_id              = aws_subnet.private_subnet_1.id
  key_name               = "slave"
  vpc_security_group_ids = [aws_security_group.private_sg.id]

  tags = {
    Name = "KafkaPrivate1"
  }
}

resource "aws_instance" "private_instance_2" {
  ami                    = "ami-021a584b49225376d" # Replace with your AMI
  instance_type          = "t3.medium"
  subnet_id              = aws_subnet.private_subnet_2.id
  key_name               = "slave"
  vpc_security_group_ids = [aws_security_group.private_sg.id]

  tags = {
    Name = "KafkaPrivate2"
  }
}


resource "aws_lb" "kafka_nlb" {
  name               = "kafka-nlb"
  internal           = false
  load_balancer_type = "network"
  security_groups    = [aws_security_group.public_sg.id]
  subnets = [
    aws_subnet.public_subnet_1.id,
    aws_subnet.public_subnet_2.id
  ]

}

resource "aws_lb_target_group" "kafka_tg" {
  name     = "kafka-tg"
  port     = 9092
  protocol = "TCP"
  vpc_id   = aws_vpc.main.id

  health_check {
    protocol            = "TCP"
    port                = "9092"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 10
    timeout             = 5
  }
}


resource "aws_lb_target_group_attachment" "tg_attach_private_1" {
  target_group_arn = aws_lb_target_group.kafka_tg.arn
  target_id        = aws_instance.private_instance_1.id
  port             = 9092
}

resource "aws_lb_target_group_attachment" "tg_attach_private_2" {
  target_group_arn = aws_lb_target_group.kafka_tg.arn
  target_id        = aws_instance.private_instance_2.id
  port             = 9092
}


resource "aws_lb_listener" "kafka_listener" {
  load_balancer_arn = aws_lb.kafka_nlb.arn
  port              = 9092
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.kafka_tg.arn
  }
}
