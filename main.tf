# aws vpc creation
resource "aws_vpc" "main" {
  cidr_block            = var.address_space
  instance_tenancy      = "default"
  enable_dns_hostnames  = true
  enable_dns_support    = true
  assign_generated_ipv6_cidr_block = false

  tags = {
    name = "${var.prefix}-vpc-main"
  }
}

# aws subnet creation to host the webserver
resource "aws_subnet" "front-end-network" {
  vpc_id = "${aws_vpc.main.id}"
  cidr_block = "${element(var.public_subnet, count.index)}"
  availability_zone = "${element(var.availability_zones, count.index)}"
  count      = "${length(var.public_subnet)}"
  map_public_ip_on_launch = true
  lifecycle { create_before_destroy = true }
  tags = {
    Name = "front-end-network_${count.index}"
  }
}


## Aws Internet Gateway Resource creation
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.prefix}-internet-gateway"
  }
}

## Aws default route table routing configuration
resource "aws_default_route_table" "public" {
    default_route_table_id = aws_vpc.main.default_route_table_id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw.id
    }

    tags = {
        Name = "${var.prefix}_public_route_table"
    }
    lifecycle { create_before_destroy = true }
}


# Associate route table with route configuration
resource "aws_route_table_association" "public" {
    
    subnet_id = "${element(aws_subnet.front-end-network.*.id, count.index)}"
    route_table_id = aws_vpc.main.default_route_table_id
    count = "${length(var.availability_zones)}"
    lifecycle { create_before_destroy = true }

}

// Create a security group to access the server

resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh_sg"
  description = "Allow SSH inbound connections"
  vpc_id = "${aws_vpc.main.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

# Security Group allowing HTTP traffic to load balancer from anywhere (not directly to the instance(s))

resource "aws_security_group" "elb_sg" {
  name = "${var.prefix}_security_group_for_elb"
  vpc_id = "${aws_vpc.main.id}"
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}


## SG for web instances
resource "aws_security_group" "web_sg" {
  name = "security_group_for_web_server"
  vpc_id = "${aws_vpc.main.id}"
  ingress {
    from_port = 5000
    to_port = 5000
    protocol = "tcp"
    security_groups = ["${aws_security_group.elb_sg.id}"]
 }
 lifecycle {
    create_before_destroy = true
 }
}


### Creating ELB

resource "aws_elb" "elb" {
  name = "${var.prefix}-elb"
  subnets = aws_subnet.front-end-network.*.id
  security_groups = [aws_security_group.elb_sg.id]
  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 2
    timeout = 3
    interval = 30
    target = "HTTP:5000/"
  }
  listener {
    lb_port = 80
    lb_protocol = "http"
    instance_port = "5000"
    instance_protocol = "http"
  }
}

# Create an SSH key
resource "tls_private_key" "terraform_ssh" {
  algorithm = "RSA"
  rsa_bits = 4096
}

resource local_file private_key {
    sensitive_content = tls_private_key.terraform_ssh.private_key_pem
    filename = "ca-key.pem"
    file_permission = "0400"
}

resource aws_key_pair pub_key {
    public_key = tls_private_key.terraform_ssh.public_key_openssh
    key_name = "ca-key.pub" 
    depends_on = [tls_private_key.terraform_ssh]

}

## Creating Launch Configuration
resource "aws_launch_configuration" "as_launch_config" {
  image_id               = data.aws_ami.ubuntu.id 
  instance_type          = "t2.micro"
  security_groups        = ["${aws_security_group.web_sg.id}", "${aws_security_group.allow_ssh.id}"]
  key_name               = "${aws_key_pair.pub_key.key_name}"
  associate_public_ip_address = true
  iam_instance_profile = aws_iam_instance_profile.demo_profile.name
  user_data =<<-EOF
              #!/usr/bin/env bash
              sudo apt-get update -y
              sudo apt install awscli apt-transport-https ca-certificates curl software-properties-common -y
              curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
              sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"
              sudo apt update
              sudo apt install docker-ce -y
              sudo usermod -aG docker ubuntu
              sudo apt update -y
              sudo curl -L "https://github.com/docker/compose/releases/download/1.26.2/docker-compose-Linux-x86_64" -o /usr/local/bin/docker-compose
              sudo chmod +x /usr/local/bin/docker-compose 
              cd /home/ubuntu/
              aws s3 sync s3://via-python-roject-001 .
              docker build -t python-app-demo .
              docker run --name=python-app-demo -d -p 5000:5000 python-app-demo:latest
              sudo chmod 755 check_docker_container.sh
              sudo su
              echo '* * * * *  /bin/bash /home/ubuntu/check_docker_container.sh'  > /tmp/check_docker_container.txt
              sudo -u root bash -c 'crontab /tmp/check_docker_container.txt'
              EOF
  lifecycle {
    create_before_destroy = true
  }
  depends_on = [aws_key_pair.pub_key]
}

## Creating AutoScaling Group
resource "aws_autoscaling_group" "web_as_group" {
  launch_configuration = "${aws_launch_configuration.as_launch_config.id}"
  vpc_zone_identifier       = aws_subnet.front-end-network.*.id
  min_size = 2
  max_size = 5
  load_balancers = ["${aws_elb.elb.name}"]
  health_check_type = "ELB"
  enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupTotalInstances"
  ]

  tag {
    key = "Name"
    value = "${var.prefix}_private_subnet_route_table"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "web_policy_up" {
  name = "web_policy_up"
  scaling_adjustment = 1
  adjustment_type = "ChangeInCapacity"
  cooldown = 300
  autoscaling_group_name = "${aws_autoscaling_group.web_as_group.name}"
}

resource "aws_autoscaling_policy" "web_policy_down" {
  name = "web_cpu_alarm_down"
  scaling_adjustment = -1
  adjustment_type = "ChangeInCapacity"
  cooldown = 300
  autoscaling_group_name = "${aws_autoscaling_group.web_as_group.name}"
}
