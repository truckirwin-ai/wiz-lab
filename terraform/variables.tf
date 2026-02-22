variable "aws_region" {
  description = "AWS region"
  default     = "us-east-1"
}

variable "account_id" {
  description = "AWS account ID (used for unique S3 bucket naming)"
  default     = "180294223177"
}

variable "key_pair_name" {
  description = "EC2 key pair name"
  default     = "wiz-lab-key"
}
