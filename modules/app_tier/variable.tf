variable "vpc_id" {
  description = "The VPC ID"
}
variable "name" {
       description = "App Name"
}
variable "ami_id" {
       description = "AMI ID"
}
variable "igw" {
  description = "Gateway ID Variable"
}

#
# variable "pub_ip" {
#   description = "the generated ip"
# }
#
variable "db_private_ip" {
  description = "the ip of the db instance"
}
