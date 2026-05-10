output "alb_url"          {
     value = "http://${module.alb.alb_dns_name}"
      }


output "ssh_key_file"     { 
    value = "${var.project_name}-key.pem" 
    }

output "public_ip" {
value = module.ec2_app.public_ip
}
output "instance_id" {
value = one(module.ec2_app.instance_ids)
}
