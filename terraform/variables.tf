variable "aws_region"         { 
    type = string 
     default = "eu-north-1" 
     }
variable "project_name"       { 
    type = string 
     default = "my-app"
      }
variable "ami_id"             { 
    type = string  
    default = "ami-05d62b9bc5a6ca605"
     }
variable "app_instance_type"  {
     type = string
       default = "t3.micro"
        }
variable "app_instance_count"{
     type = number 
      default = 1 
      }
variable "app_port"           {
     type = number 
      default = 8080
       }

variable "notification_email" {
     type = string 
      default = "kavyachakkapalli@gmail.com"
       }
variable "allowed_admin_cidr" { 
    type = string 
     default = "0.0.0.0/0"
      }


