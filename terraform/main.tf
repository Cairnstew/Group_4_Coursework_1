provider "aws" {
  region = "us-east-1"
}

# 2. Look up the default VPC
data "aws_vpc" "default" {
  default = true
}

# 3. Look up the first subnet in the default VPC
data "aws_subnets" "defualt_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}


# 4. Security Group to allow ports 8080 and 9000
resource "aws_security_group" "app_sg" {
  name        = "app-server-sg"
  description = "Allow 8080 and 9000 traffic"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow 8080 from anywhere"
  }

  ingress {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow 9000 from anywhere"
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow SSH from anywhere"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "app-server-sg"
  }
}


resource "aws_instance" "app_server" {
  ami           = "ami-0071174ad8cbb9e17"
  instance_type = "t2.large"
  key_name      = "vockey" 

  subnet_id              = data.aws_subnets.defualt_subnets.ids[0]
  vpc_security_group_ids = [aws_security_group.app_sg.id]

  associate_public_ip_address = true

  root_block_device {
    volume_size = 25    # GB
    volume_type = "gp3" # gp3 is cheaper and faster than default gp2
    encrypted   = true
  }

  user_data = templatefile("${path.module}/scripts/bootstrap.sh.tpl", {
    app_port       = 8080
    environment    = "production"
    docker_compose = file("${path.module}/docker-compose.yaml")
    jenkins_casc   = file("${path.module}/jenkins/casc.yaml")
    dockerfile     = file("${path.module}/jenkins/Dockerfile")
  })


  tags = { 
    Name = "Group_4_Coursework_1_App_Server"
  }
}

output "ssh_command" {
  value = "ssh -i <path_to_pem> ubuntu@${aws_instance.app_server.public_ip}"
}
