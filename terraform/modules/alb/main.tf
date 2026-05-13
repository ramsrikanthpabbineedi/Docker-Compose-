resource "aws_lb" "this" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = false
  
  tags = { 
    Name = "${var.project_name}-alb" 
  }
}

resource "aws_lb_target_group" "this" {
  name     = "${var.project_name}-tg"
  port     = var.app_port
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  # Graceful connection draining
  deregistration_delay = 30

  health_check {
    # Port the health check uses
    port                = "traffic-port"
    path                = var.health_check_path
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200-399"
    enabled             = true
  }

  tags = { 
    Name = "${var.project_name}-tg" 
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}

# Attach EC2 instances to the target group
resource "aws_lb_target_group_attachment" "this" {
  count            = length(var.target_instance_ids)
  target_group_arn = aws_lb_target_group.this.arn
  target_id        = var.target_instance_ids[count.index]
  port             = var.app_port
  
  # Ensure target group is fully created before attaching
  depends_on = [aws_lb_target_group.this]
}
