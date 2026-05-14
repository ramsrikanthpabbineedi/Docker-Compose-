variable "project_name"       {
     type = string 
     }
variable "vpc_id"             { 
    type = string
     }
variable "app_port"           { 
    type = number  
    default = 80
    }
variable "allowed_admin_cidr" { 
    type = string  
    default = "0.0.0.0/0" 
    }