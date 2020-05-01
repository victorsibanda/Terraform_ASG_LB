
resource "aws_subnet" "app_subnet" {
  vpc_id     = var.vpc_id
  cidr_block = "10.0.1.0/24"
  availability_zone = "eu-west-1a"
  tags = {
    Name = "${var.name}-subnet"
  }
}

#network_acl_id
resource "aws_network_acl" "public_nacl" {
  vpc_id = var.vpc_id
  subnet_ids = [aws_subnet.app_subnet.id]

  egress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }
  ingress {
    protocol   = "tcp"
    rule_no    = 110
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }
  ingress {
    protocol   = "tcp"
    rule_no    = 120
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 3000
    to_port    = 3000
  }
  ingress {
    protocol   = "tcp"
    rule_no    = 130
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }
  ingress {
    protocol   = "tcp"
    rule_no    = 140
    action     = "allow"
    cidr_block = "85.255.236.170/32"
    from_port  = 22
    to_port    = 22
  }
  ingress {
    protocol   = "tcp"
    rule_no    = 150
    action     = "allow"
    cidr_block = "10.0.2.0/24"
    from_port  = 27017
    to_port    = 27017
  }

  tags = {
    Name = "${var.name}-public-NACL"
  }
}

# Route Table
resource "aws_route_table" "public" {

vpc_id = var.vpc_id

route {
    cidr_block = "0.0.0.0/0"
    gateway_id = var.igw
  }
  tags = {
    Name = "Route-Table-${var.name}-public"
  }
}

resource "aws_route_table_association" "main" {
  subnet_id      = aws_subnet.app_subnet.id
  route_table_id = aws_route_table.public.id
}



resource "aws_security_group" "App_SG" {
  name        = "Victor-Eng54_App-SG"
  description = "Allows for traffic on Port 80"
  vpc_id      = var.vpc_id

  ingress {
    description = "Port 80 from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Port 3000 from anywhere"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Port 22 from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["85.255.236.170/32"]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name}-SG"
  }
}


# Launching and Instance


data "template_file" "app_init" {
  template = "${file("./scripts/app/app_init.sh.tpl")}"
  vars = {
      db_priv_ip = var.db_private_ip
    }
}

# resource "aws_instance" "app_instance" {
#     ami = var.ami_id
#     instance_type = "t2.micro"
#     associate_public_ip_address = true
#     subnet_id = aws_subnet.app_subnet.id
#
#     security_groups = [aws_security_group.App_SG.id]
#     tags = {
#       Name = "Terraform-${var.name}"
#     }
#     key_name = "victor-eng54"
#     user_data = data.template_file.app_init.rendered
#
#   #   provisioner "remote-exec" {
#   #   inline = [
#   #     "cd /home/ubuntu/app",
#   #     "sudo chown -R 1000:1000 '/home/ubuntu/.npm'",
#   #     "nodejs seeds/seed.js",
#   #     "pm2 start app.js",
#   #     "echo 'done'"
#   #   ]
#   # }
#   # connection {
#   #   type     = "ssh"
#   #   user     = "ubuntu"
#   #   host = self.public_ip
#   #   private_key = "${file("~/.ssh/victor-eng54.pem")}"
#   # }
# }


### Build Target Group and Load Balancer
resource "aws_lb" "app_lb" {
  name               = "Victor-Eng54-lb-tf"
  internal           = false
  load_balancer_type = "network"
  subnets            = ["${aws_subnet.app_subnet.id}"]

  enable_deletion_protection = false

  tags = {
    Name = "${var.name}-lb-tf"
    Environment = "${var.name}-production"
  }
}


resource "aws_lb_target_group" "LB_TargetGroup" {
  name     = "Victor-Eng54-LBTG"
  port     = 80
  protocol = "TCP"
  target_type = "instance"
  vpc_id   = var.vpc_id

}

resource "aws_lb_listener" "lb_litsener" {
    load_balancer_arn = aws_lb.app_lb.arn
    port              = 80
    protocol          = "TCP"

    default_action {
      target_group_arn = aws_lb_target_group.LB_TargetGroup.arn
      type             = "forward"
    }
}


# Launch Config
#Specifies the properties of the intance AMI ID, Security Group

resource "aws_launch_configuration" "app_launchconfig" {
  name_prefix     ="vs_app_launchconfig"
  image_id        = var.ami_id
  instance_type   ="t2.micro"
  security_groups = [aws_security_group.App_SG.id]
  associate_public_ip_address = false
  key_name = "victor-eng54"
  user_data = data.template_file.app_init.rendered
  lifecycle {
    create_before_destroy = true
  }

}


# Auto Scaling Group
# Specifies the scaling properties (min instances, max instances, health checks)

data "aws_availability_zones" "all" {}


resource "aws_autoscaling_group" "app_asg" {
  vpc_zone_identifier  = ["${aws_subnet.app_subnet.id}"]
  launch_configuration = "${aws_launch_configuration.app_launchconfig.id}"
  # availability_zones = ["${data.aws_availability_zones.all.names}"]
  min_size             = 1
  max_size             = 1
  health_check_grace_period = 300
  health_check_type          ="EC2"
  force_delete = true
  target_group_arns = ["${aws_lb_target_group.LB_TargetGroup.arn}"]
  tag {
    key = "Name"
    value = "Victor-Eng54-TerraformASG"
    propagate_at_launch = true
  }
}
