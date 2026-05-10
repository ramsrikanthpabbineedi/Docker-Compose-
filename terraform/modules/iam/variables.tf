variable "project_name"      { 
    type = string 
    }
variable "role_suffix"       {
     type = string
      }
variable "policy_statements" {
     type = list(any) 
      default = [] 
      }