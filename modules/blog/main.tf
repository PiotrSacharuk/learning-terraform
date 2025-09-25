data "aws_ami" "app_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = [var.ami_filter.name]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = [var.ami_filter.owner]
}


module "blog_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.2.0"

  name = var.environment.name
  cidr = "${var.environment.network_prefix}.0.0/16"

  azs             = ["us-west-2a","us-west-2b","us-west-2c"]
  public_subnets  = ["${var.environment.network_prefix}.101.0/24", "${var.environment.network_prefix}.102.0/24", "${var.environment.network_prefix}.103.0/24"]

  tags = {
    Terraform = "true"
    Environment = var.environment.name
  }
}


resource "aws_launch_template" "blog" {
  name_prefix   = "${var.environment.name}-blog-"
  image_id      = data.aws_ami.app_ami.id
  instance_type = var.instance_type

  vpc_security_group_ids = [module.blog_sg.security_group_id]

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.environment.name}-blog"
      Environment = var.environment.name
    }
  }
}

resource "aws_autoscaling_group" "blog" {
  name                = "${var.environment.name}-blog"
  vpc_zone_identifier = module.blog_vpc.public_subnets
  target_group_arns   = [module.blog_alb.target_groups["blog-tg"].arn]
  health_check_type   = "ELB"

  min_size         = var.asg_min
  max_size         = var.asg_max
  desired_capacity = var.asg_min

  launch_template {
    id      = aws_launch_template.blog.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.environment.name}-blog-asg"
    propagate_at_launch = false
  }

  tag {
    key                 = "Environment"
    value               = var.environment.name
    propagate_at_launch = false
  }
}

module "blog_alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "10.0.0"

  name               = "${var.environment.name}-blog-alb"
  load_balancer_type = "application"

  vpc_id                = module.blog_vpc.vpc_id
  subnets               = module.blog_vpc.public_subnets
  security_groups       = [module.blog_sg.security_group_id]

  # Target groups
  target_groups = {
    blog-tg = {
      name_prefix          = "${substr(var.environment.name, 0, 6)}-"
      protocol             = "HTTP"
      port                 = 80
      target_type          = "instance"
      protocol_version     = "HTTP1"
      create_attachment    = false  # Autoscaling group zarządza attachments

      health_check = {
        enabled             = true
        healthy_threshold   = 3
        interval            = 30
        matcher             = "200"
        path                = "/"
        port                = "traffic-port"
        protocol            = "HTTP"
        timeout             = 5
        unhealthy_threshold = 3
      }
    }
  }

  # Listeners
  listeners = {
    blog-listener = {
      port     = 80
      protocol = "HTTP"

      forward = {
        target_group_key = "blog-tg"
      }
    }
  }

  tags = {
    Environment = var.environment.name
  }
}

module "blog_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.3.0"

  vpc_id  = module.blog_vpc.vpc_id
  name    = "${var.environment.name}-blog"
  ingress_rules = ["https-443-tcp","http-80-tcp"]
  ingress_cidr_blocks = ["0.0.0.0/0"]
  egress_rules = ["all-all"]
  egress_cidr_blocks = ["0.0.0.0/0"]
}
