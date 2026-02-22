provider "aws" {
  region = var.aws_region
}

# -------------------------------------------------------
# VPC
# -------------------------------------------------------
resource "aws_vpc" "wiz_lab" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "wiz-lab-vpc" }
}

resource "aws_internet_gateway" "wiz_lab" {
  vpc_id = aws_vpc.wiz_lab.id
  tags   = { Name = "wiz-lab-igw" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.wiz_lab.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true  # checkov finding: CKV_AWS_130
  availability_zone       = "${var.aws_region}a"
  tags = { Name = "wiz-lab-public" }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.wiz_lab.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${var.aws_region}a"
  tags = { Name = "wiz-lab-private" }
}

# -------------------------------------------------------
# Security Group — SSH open to the world (INTENTIONAL MISCONFIGURATION)
# -------------------------------------------------------
resource "aws_security_group" "mongo_ec2" {
  name        = "wiz-lab-mongo-sg"
  description = "Security group for MongoDB EC2"
  vpc_id      = aws_vpc.wiz_lab.id

  # INTENTIONAL MISCONFIGURATION: SSH open to 0.0.0.0/0
  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # checkov finding: CKV_AWS_24
  }

  ingress {
    description = "MongoDB"
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # checkov finding: CKV_AWS_25
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "wiz-lab-mongo-sg" }
}

# -------------------------------------------------------
# IAM — Overly permissive role (INTENTIONAL MISCONFIGURATION)
# -------------------------------------------------------
resource "aws_iam_role" "ec2_role" {
  name = "wiz-lab-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

# INTENTIONAL MISCONFIGURATION: AdministratorAccess on EC2 role
resource "aws_iam_role_policy_attachment" "ec2_admin" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"  # checkov finding: CKV_AWS_274
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "wiz-lab-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

# -------------------------------------------------------
# S3 — Public bucket (INTENTIONAL MISCONFIGURATION)
# -------------------------------------------------------
resource "aws_s3_bucket" "backups" {
  bucket        = "wiz-lab-backups-${var.account_id}"
  force_destroy = true
  tags = { Name = "wiz-lab-backups" }
}

# INTENTIONAL MISCONFIGURATION: Block public access disabled
resource "aws_s3_bucket_public_access_block" "backups" {
  bucket = aws_s3_bucket.backups.id

  block_public_acls       = false  # checkov finding: CKV_AWS_53
  block_public_policy     = false  # checkov finding: CKV_AWS_54
  ignore_public_acls      = false  # checkov finding: CKV_AWS_55
  restrict_public_buckets = false  # checkov finding: CKV_AWS_56
}

resource "aws_s3_bucket_policy" "backups_public" {
  bucket     = aws_s3_bucket.backups.id
  depends_on = [aws_s3_bucket_public_access_block.backups]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "PublicReadGetObject"
      Effect    = "Allow"
      Principal = "*"  # checkov finding: CKV_AWS_70
      Action    = ["s3:GetObject", "s3:ListBucket"]
      Resource  = [
        "arn:aws:s3:::wiz-lab-backups-${var.account_id}",
        "arn:aws:s3:::wiz-lab-backups-${var.account_id}/*"
      ]
    }]
  })
}

# No bucket encryption (checkov finding: CKV_AWS_19)
# No bucket logging   (checkov finding: CKV_AWS_18)
# No bucket versioning (checkov finding: CKV_AWS_21)

# -------------------------------------------------------
# EC2 — MongoDB instance
# -------------------------------------------------------
resource "aws_instance" "mongo" {
  ami                    = "ami-0453ec754f44f9a4a"  # Amazon Linux 2023
  instance_type          = "t3.medium"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.mongo_ec2.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  key_name               = var.key_pair_name

  # No EBS encryption (checkov finding: CKV_AWS_8)
  root_block_device {
    encrypted = false  # checkov finding: CKV_AWS_8
  }

  # IMDSv1 not explicitly disabled (checkov finding: CKV_AWS_79)
  metadata_options {
    http_tokens = "optional"
  }

  user_data = <<-EOF
    #!/bin/bash
    cat > /etc/yum.repos.d/mongodb-org-6.0.repo << 'REPO'
    [mongodb-org-6.0]
    name=MongoDB Repository
    baseurl=https://repo.mongodb.org/yum/amazon/2023/mongodb-org/6.0/x86_64/
    gpgcheck=1
    enabled=1
    gpgkey=https://www.mongodb.org/static/pgp/server-6.0.asc
    REPO
    dnf install -y mongodb-org
    systemctl start mongod && systemctl enable mongod
  EOF

  tags = { Name = "wiz-lab-mongo" }
}
