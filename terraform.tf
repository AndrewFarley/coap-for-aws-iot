# Minimum version requirements for terraform
terraform {
    required_version = ">= 0.11.1"
}

# The provider we'll be working with, AWS
provider "aws" {
    region = "${var.region}"
    version = "> 1.8.0"
}

locals {
  stack_name  = "coap-${var.stage}"
}

############## VARS #############

variable "region" {  
  description = "The AWS region we wish to deploy into"
  default = "eu-west-1"
}

variable "stage" {
  default = "dev"
}

# This is a helper we'll use often to get our AWS account id, used in ARNs and such
data "aws_caller_identity" "current" {}

# This is the instance size
variable "instance_size" {
    default = "t2.nano"
}

# This gets the latest official ubuntu AMI on our region
data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"] # Canonical
}

############## RESOURCES #############

resource "aws_sqs_queue" "terraform_queue" {
  name                      = "${local.stack_name}"
  delay_seconds             = 5
  max_message_size          = 2048
  message_retention_seconds = 1209600  # 86400 = 1 day, 1209600 = 14 days (max)
  receive_wait_time_seconds = 10
  # redrive_policy            = "{\"deadLetterTargetArn\":\"${aws_sqs_queue.terraform_queue_deadletter.arn}\",\"maxReceiveCount\":4}"
  # tags {
  #   Environment = "production"
  # }
}

# Temporarily just use the person who ran this terraform's public SSH key, so we can get in and test
resource "aws_key_pair" "demo_keypair" {
    key_name = "${local.stack_name}_keypair"
    public_key = "${file("~/.ssh/id_rsa.pub")}"
}



data "template_file" "init" {
  template = "${file("${path.module}/user_data.sh")}"
  vars {
    AWS_ACCESS_KEY_ID     = "${aws_iam_access_key.demo.id}"
    AWS_SECRET_ACCESS_KEY = "${aws_iam_access_key.demo.secret}"
    AWS_DEFAULT_REGION    = "${var.region}"
    SQS_QUEUE_NAME        = "${aws_sqs_queue.terraform_queue.name}"
  }
}

resource "aws_iam_user" "demo" {
  name = "coap-push-to-sqs"
  path = "/system/"
}

resource "aws_iam_user_policy" "demo_ro" {
  name = "test"
  user = "${aws_iam_user.demo.name}"

  policy = <<EOF
{
      "Version": "2012-10-17",
      "Statement": [
          {
              "Sid": "VisualEditor0",
              "Effect": "Allow",
              "Action": [
                  "sqs:ListQueues",
                  "sqs:GetQueueUrl",
                  "sqs:ListDeadLetterSourceQueues",
                  "sqs:SendMessageBatch",
                  "sqs:SendMessage",
                  "sqs:GetQueueAttributes",
                  "sqs:ListQueueTags"
              ],
              "Resource": "*"
          }
      ]
}
EOF
}

resource "aws_iam_access_key" "demo" {
  user    = "${aws_iam_user.demo.name}"
}

output "access_key_id" {
  value       = ["${aws_iam_access_key.demo.id}"]
}
output "access_key_secret" {
  value       = ["${aws_iam_access_key.demo.secret}"]
}

# Spins up a _simple as hell_ host
resource "aws_instance" "demo" {
  ami                         = "${data.aws_ami.ubuntu.id}"
  instance_type               = "${var.instance_size}"
  associate_public_ip_address = true
  security_groups             = ["${aws_security_group.allow_ssh_and_coap.name}"]
  key_name                    = "${aws_key_pair.demo_keypair.key_name}"
  tags {
    Name = "${local.stack_name}"
  }
  user_data                   = "${data.template_file.init.rendered}"
}

resource "aws_eip" "demo" {
  instance = "${aws_instance.demo.id}"
  vpc      = true
}

#### OUTPUT ####
output "public_ip" {
  description = "The public IP(s) of this instance (if exists)"
  value       = ["${aws_eip.demo.public_ip}"]
}

# For now just allow SSH from anywhere
resource "aws_security_group" "allow_ssh_and_coap" {
  name        = "${local.stack_name}-allow_ssh_and_coap"
  description = "Allow SSH and CoAP"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5683
    to_port     = 5693
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}
