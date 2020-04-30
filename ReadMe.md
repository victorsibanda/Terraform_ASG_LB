# 2-Tier Terraform

Terraform is an Orchestration Tool, that is part of infrastructure as code.
Where Chef and Packer sit more on **Configuration Management** Side and create immutable AMIs. Terraform sits on the **orchestration side**. This includes the creation of networks and complex systems and deploys AMIs.

Terraform is a tool for building, changing, and versioning infrastructure safely and efficiently. Terraform can manage existing and popular service providers as well as custom in-house solutions.


Configuration files describe to Terraform the components needed to run a single application or your entire datacenter. Terraform generates an execution plan describing what it will do to reach the desired state, and then executes it to build the described infrastructure. As the configuration changes, Terraform is able to determine what changed and create incremental execution plans which can be applied.

## Description

This repo allows you to launch an Auto Scaling group which provisions an application which is linked to a database. This Application is live as working when you launch the terraform. There are two modules used a db_tier and a module_tier each tier is relevant for private and public. In addition the as I am using a auto scaling group and a load balancer, if one of the instance's require a greater capacity it will scale out.


## Usage

- To use this repo you will have to edit the AWS key_name to yours and its file location.

### Prerequisites

- Terraform
- Git
- AWS CLI 2

### Cloning Repository

```sh
git clone git@github.com:victorsibanda/Terraform_ASG_LB.git
```

### Terraform Commands

- To Initialise folder to use terraform use
```sh
terraform init
```

- Test's to see if you have necessary AWS resources
```sh
terraform plan
```

- Applies the changes on main.tf which run the app
```sh
terraform apply
```

- To destroy all resources created by terraform
```sh
terraform destroy
```

## Running Scripts

### Template

To run scripts you would use, templates and, create a template file in that repo. The filename would be `{name}.sh.tpl`.

- The Syntax is
```hcl
data "template_file" "init" {
  template = "${file("${path.module}/init.tpl")}"
  vars = {
    consul_address = "${aws_instance.consul.private_ip}"
  }
}
```

### Remote Exec

Alternatively you could use remote exec which allows you to run inline commands but you will need to move over your key pair to allow AWS to use it to ssh into the machine to run the command.

- The syntax is:
```hcl
provisioner "remote-exec" {
    inline = [
      "puppet apply",
      "consul join ${aws_instance.web.private_ip}",
    ]
  }

```

# 2-Tier Architecture

When using terraform you can use it to make 2-tier architecture.  In this case I created an "App" and a "DB" using modules and I am launching 2 EC2's which comunicate with each other.

## Modules

The syntax used when creating Modules on the main.tf file is

```hcl

module "app" {
  source = "./modules/app_tier"
  vpc_id = aws_vpc.app_vpc.id
  ami_id = var.ami_id
  name = var.name
  igw = aws_internet_gateway.igw.id
  # pub_ip = module.db.pub_ip
  db_private_ip = module.db.db_private_ip
}

```

The tree for a complete module is as below:

```python
$ tree complete-module/
.
├── README.md
├── main.tf
├── variables.tf
├── outputs.tf
├── ...
├── modules/
│   ├── nestedA/
│   │   ├── README.md
│   │   ├── variables.tf
│   │   ├── main.tf
│   │   ├── outputs.tf
│   ├── nestedB/
│   ├── .../
├── examples/
│   ├── exampleA/
│   │   ├── main.tf
│   ├── exampleB/
│   ├── .../
```

## Injecting Environment variables

To connect the database to the app I had to use Environment variables and took 3 steps to improve make it work

#### Adding Outputs Line in db_tier/main.tf
```hcl
output "db_private_ip" {
  value = aws_instance.db_instance.private_ip
}

```
#### Including the line within the script `scripts/app/app_init.sh.tpl` and adding it to the `app_tier/main.tf`

---
```sh
echo "export DB_HOST='mongodb://${db_priv_ip}:27017/posts'" >> /home/ubuntu/.bashrc
echo "export DB_HOST='mongodb://${db_priv_ip}:27017/posts'" >> /home/ubuntu/.profile
source /home/ubuntu/.bashrc
source /home/ubuntu/.profile
```
```hcl
data "template_file" "app_init" {
  template = "${file("./scripts/app/app_init.sh.tpl")}"
  vars = {
      db_priv_ip = var.db_private_ip
    }
}
```
---
#### Adding it to app_tier Variable and including it on main.tf
```hcl

variable "db_private_ip" {
  description = "the ip of the db instance"
}

#// Main.tf// App Module

db_private_ip = module.db.db_private_ip

```

# ASG and Load Balancers

#### - To set up an Load Balancer I used the syntax as shown below.

---
```hcl
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

```
---

#### - To set up an auto scaling group I used the syntax as shown below.

---
```hcl
# Launch Config
#Specifies the properties of the intance AMI ID, Security Group

resource "aws_launch_configuration" "app_launchconfig" {
  name_prefix     ="vs_app_launchconfig"
  image_id        = var.ami_id
  instance_type   ="t2.micro"
  security_groups = [aws_security_group.App_SG.id]
  associate_public_ip_address = true
  key_name = ""
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
  tag {
    key = "Name"
    value = "Victor-Eng54-TerraformASG"
    propagate_at_launch = true
  }
}
```
---
