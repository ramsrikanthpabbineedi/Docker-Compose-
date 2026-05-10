variable "project_name"          { 
    type = string 
    }
variable "ami_id"                {
     type = string 
     
     }
variable "instance_type"         {
     type = string 
      default = "t3.medium" 
      }
variable "instance_count"        {
     type = number  
     default = 1
      }
variable "key_name"              { 
    type = string
     }
variable "subnet_ids"            { 
    type = list(string)
    
     }
variable "security_group_id"     { 
    type = string
    
     }
variable "instance_profile_name" {
     type = string
      }

variable "sns_topic_arn"         {
     type = string
      }
variable "aws_region"            { 
    type = string 
    }
variable "public_ip" {
type    = bool
default = true
}
