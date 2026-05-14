module "vpc" {
  source       = "./modules/vpc"
  project_name = var.project_name
}

module "security" {
  source       = "./modules/security"
  project_name = var.project_name
  vpc_id       = module.vpc.vpc_id
  app_port     = var.app_port

}

module "keypair" {
  source       = "./modules/keypair"
  project_name = var.project_name
}

module "sns" {
  source             = "./modules/sns"
  project_name       = var.project_name
  notification_email = var.notification_email
}

module "iam_app" {
  source       = "./modules/iam"
  project_name = var.project_name
  role_suffix  = "app"
  policy_statements = [{
    Effect   = "Allow"
    Action   = ["sns:Publish"]
    Resource = module.sns.topic_arn
  }]
}

module "iam_jenkins" {
  source       = "./modules/iam"
  project_name = var.project_name
  role_suffix  = "jenkins"
  policy_statements = [
    {
      Effect   = "Allow"
      Action   = ["ec2:Describe*", "ec2-instance-connect:SendSSHPublicKey"]
      Resource = "*"
    },
    {
      Effect   = "Allow"
      Action   = ["sns:Publish"]
      Resource = module.sns.topic_arn
    }
  ]
}

module "ec2_app" {
  source                = "./modules/ec2"
  project_name          = var.project_name
  ami_id                = var.ami_id
  instance_type         = var.app_instance_type
  instance_count        = var.app_instance_count
  key_name              = module.keypair.key_name
  subnet_ids            = module.vpc.public_subnet_ids
  security_group_id     = module.security.app_sg_id
  instance_profile_name = module.iam_app.instance_profile_name
  sns_topic_arn         = module.sns.topic_arn
  aws_region            = var.aws_region
  public_ip             = true

}

module "alb" {
  source              = "./modules/alb"
  project_name        = var.project_name
  vpc_id              = module.vpc.vpc_id
  public_subnet_ids   = module.vpc.public_subnet_ids
  alb_sg_id           = module.security.alb_sg_id
  target_instance_ids = module.ec2_app.instance_ids
}
# terraform/main.tf

