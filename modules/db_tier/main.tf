
resource "aws_subnet" "db_subnet" {
  vpc_id     = var.vpc_id
  cidr_block = "10.0.2.0/24"
  availability_zone = "eu-west-1a"
  tags = {
    Name = "${var.name}-private-subnet"
  }
}

#network_acl_id
resource "aws_network_acl" "db_private_nacl" {
  vpc_id = var.vpc_id
  subnet_ids = [aws_subnet.db_subnet.id]

  egress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "10.0.1.0/24"
    from_port  = 22
    to_port    = 22
  }
  egress {
    protocol   = "tcp"
    rule_no    = 110
    action     = "allow"
    cidr_block = "10.0.1.0/24"
    from_port  = 27017
    to_port    = 27017
  }
  egress {
    protocol   = "tcp"
    rule_no    = 120
    action     = "allow"
    cidr_block = "10.0.1.0/24"
    from_port  = 1024
    to_port    = 65535
  }


  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "10.0.1.0/24"
    from_port  = 1024
    to_port    = 65535
  }
  ingress {
    protocol   = "tcp"
    rule_no    = 110
    action     = "allow"
    cidr_block = "10.0.1.0/24"
    from_port  = 27017
    to_port    = 27017
  }
  ingress {
    protocol   = "tcp"
    rule_no    = 120
    action     = "allow"
    cidr_block = "10.0.1.0/24"
    from_port  = 22
    to_port    = 22
  }

  tags = {
    Name = "${var.name}-private-NACL"
  }
}

resource "aws_route_table" "private" {
  vpc_id = var.vpc_id

    tags = {
      Name = "${var.name}-private-route_table"
    }
}

resource "aws_route_table_association" "assoc" {
  subnet_id = aws_subnet.db_subnet.id
  route_table_id = aws_route_table.private.id

}

resource "aws_security_group" "db_SG" {
  name        = "DB Security Group"
  description = "Private securiy Group"
  vpc_id      = var.vpc_id


  ingress {
    description = "Port 22 from public subnet"
    from_port   = 1024
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["10.0.1.0/24"]
  }

  ingress {
    description = "Port 27107 from public subnet"
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = ["10.0.1.0/24"]
  }
  ingress {
    description = "Port 27107 from public subnet"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.1.0/24"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name}-DB-SG"
  }
}

# Launching Instance


data "template_file" "db_init" {
  template = "${file("./scripts/db/db_init.sh.tpl")}"
}

resource "aws_instance" "db_instance" {
     ami   = var.db_ami_id
    instance_type = "t2.micro"
    associate_public_ip_address = true
    subnet_id = aws_subnet.db_subnet.id
    vpc_security_group_ids = [aws_security_group.db_SG.id]
    tags = {
        Name = "${var.name}-DB"
    }
    key_name = "victor-eng54"
    user_data = data.template_file.db_init.rendered

}
