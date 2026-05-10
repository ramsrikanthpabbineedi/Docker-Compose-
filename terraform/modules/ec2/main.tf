

resource "aws_instance" "this" {
  count                  = var.instance_count
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = var.subnet_ids[count.index % length(var.subnet_ids)]
  vpc_security_group_ids = [var.security_group_id]
  iam_instance_profile   = var.instance_profile_name
  associate_public_ip_address = var.public_ip

  
  tags = {
    Name = "${var.project_name}-app-${count.index + 1}"
    Role = "app"
  }

    user_data_replace_on_change = true

}