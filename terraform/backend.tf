terraform {
  backend "s3" {
    bucket         = "myapp-tfstate-kavya-2024"   # From bootstrap output
    key            = "myapp/prod/terraform.tfstate"
    region         = "eu-north-1"
    
    encrypt        = true

    # Optional: workspace-specific paths
    # workspace_key_prefix = "env"
  }
}