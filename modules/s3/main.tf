resource "aws_s3_bucket" "bucket" {
  count = var.number_of_buckets 
  bucket = format("%s-%s-%s-bucket", "${var.owner}", "${var.project}", "${var.environment}")

  tags = {
    Name        = format("%s-%s-%s-bucket", "${var.owner}", "${var.project}", "${var.environment}")
    Environment = var.environment
  }
}

resource "aws_s3_bucket_website_configuration" "website" {
  count = var.static_site.is_static_site == true ? var.number_of_buckets : 0 
  bucket = aws_s3_bucket.bucket[count.index].id

  index_document {
    suffix = var.static_site.index_document
  }

  error_document {
    key = var.static_site.error_document
  }

  routing_rule {
    condition {
      key_prefix_equals = var.static_site.routing_rule_condition
    }
    redirect {
      replace_key_prefix_with = var.static_site.routing_rule_redirect
    }
  }
}