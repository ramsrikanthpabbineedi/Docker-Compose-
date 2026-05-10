resource "aws_iam_role" "ec2" {
  name = "${var.project_name}-${var.role_suffix}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "this" {
  count  = length(var.policy_statements) > 0 ? 1 : 0
  name   = "${var.project_name}-${var.role_suffix}-policy"
  role   = aws_iam_role.ec2.id
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = var.policy_statements
  })
}

# Attach SSM for session-manager access (no SSH needed)
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "this" {
  name = "${var.project_name}-${var.role_suffix}-profile"
  role = aws_iam_role.ec2.name
}