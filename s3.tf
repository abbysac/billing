module "s3_bucket" {
  source = "terraform-aws-modules/s3-bucket/aws"

  bucket = "email-map-s3-bucket"
  acl    = "private"

  control_object_ownership = true
  object_ownership         = "BucketOwnerEnforced"

  versioning = {
    enabled = true
  }
}