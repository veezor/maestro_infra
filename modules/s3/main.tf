resource "aws_s3_bucket" "bucket" {
  bucket = var.name

  tags = {
    Name        = var.name
    Environment = var.environment
    Project     = var.project
    Owner       = var.owner
  }
}