output "instance_ids"        { value = aws_instance.this[*].id }
output "instance_private_ips" { value = aws_instance.this[*].private_ip }
output "public_ip" {
    value = aws_instance.this[0].public_ip
  
}

