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
  version = "~> 5.0"

  name = var.environment.name
  cidr = "${var.environment.network_prefix}.0.0/16"

  azs             = ["us-west-2a","us-west-2b","us-west-2c"]
  public_subnets  = ["${var.environment.network_prefix}.101.0/24", "${var.environment.network_prefix}.102.0/24", "${var.environment.network_prefix}.103.0/24"]

  tags = {
    Terraform = "true"
    Environment = var.environment.name
  }
}


module "blog_autoscaling" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "7.4.1"

  name = "${var.environment.name}-blog"

  min_size            = var.asg_min
  max_size            = var.asg_max
  vpc_zone_identifier = module.blog_vpc.public_subnets
  target_group_arns   = [module.blog_alb.target_groups["blog-tg"].arn]
  security_groups     = [module.blog_sg.security_group_id]
  instance_type       = var.instance_type
  image_id            = data.aws_ami.app_ami.id
}

module "blog_alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 9.0"

  name               = "${var.environment.name}-blog-alb"
  load_balancer_type = "application"

  vpc_id                = module.blog_vpc.vpc_id
  subnets               = module.blog_vpc.public_subnets
  security_groups       = [module.blog_sg.security_group_id]

  # Target groups
  target_groups = {
    blog-tg = {
      name_prefix      = "${substr(var.environment.name, 0, 6)}-"
      protocol         = "HTTP"
      port             = 80
      target_type      = "instance"
      protocol_version = "HTTP1"
    }
  }

  # Listeners
  listeners = {
    blog-listener = {
      port     = 80
      protocol = "HTTP"

      default_actions = [{
        type               = "forward"
        target_group_key   = "blog-tg"
      }]
    }
  }

  tags = {
    Environment = var.environment.name
  }
}

module "blog_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  vpc_id  = module.blog_vpc.vpc_id
  name    = "${var.environment.name}-blog"
  ingress_rules = ["https-443-tcp","http-80-tcp"]
  ingress_cidr_blocks = ["0.0.0.0/0"]
  egress_rules = ["all-all"]
  egress_cidr_blocks = ["0.0.0.0/0"]
}
