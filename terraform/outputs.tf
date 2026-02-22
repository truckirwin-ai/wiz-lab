output "mongo_public_ip" {
  description = "Public IP of the MongoDB EC2 instance"
  value       = aws_instance.mongo.public_ip
}

output "s3_backup_bucket" {
  description = "Name of the public S3 backup bucket"
  value       = aws_s3_bucket.backups.bucket
}
