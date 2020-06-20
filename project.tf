provider "aws"{
    region              = "${var.region}"
}

//CREATING VPC FOR INSTANCE
resource "aws_vpc" "csye6225_awsdev"{
    cidr_block                          = "10.0.0.0/16"
    enable_dns_hostnames                = true
    enable_dns_support                  = true
    enable_classiclink_dns_support      = true
    assign_generated_ipv6_cidr_block    = false

    tags={
        Name = "csye6225_awsdev"
    }
}

//INTERNET GATEWAY
resource "aws_internet_gateway" "internet_gateway" {
  vpc_id            = "${aws_vpc.csye6225_awsdev.id}"

  tags ={
      Name          = "Internet_Gateway"
  }
}

//CREATING SUBNETS
resource "aws_subnet" "csye6225_subnet"{

    count                   = "${length(data.aws_availability_zones.availability_zones.names)}"
    vpc_id                  = "${aws_vpc.csye6225_awsdev.id}"
    //cidr_block              = "10.0.${count.index}.0/24"
    cidr_block              = "10.0.${length(data.aws_availability_zones.availability_zones.names) + count.index}.0/24"
    availability_zone       = "${element(data.aws_availability_zones.availability_zones.names, count.index)}"
    tags ={
        Name                = "public-${element(data.aws_availability_zones.availability_zones.names, count.index)}"
  }

}
//CREATING ROUTE TABLE
resource "aws_route_table" "csye6225_route_table" {

  vpc_id            = "${aws_vpc.csye6225_awsdev.id}"
}
//CREATING ROUTE
resource "aws_route" "csye6225_route" {

  route_table_id                = "${aws_route_table.csye6225_route_table.id}"
  destination_cidr_block        = "0.0.0.0/0"
  gateway_id                    = "${aws_internet_gateway.internet_gateway.id}"

}
//CREATING ROUTE TABLE ASSOCIATION
resource "aws_route_table_association" "csye6225_route_table_association" {
  //count          = "${length(var.subnet_cidrs)}"
  count                   = "${length(data.aws_availability_zones.availability_zones.names)}"  
  subnet_id               = "${element(aws_subnet.csye6225_subnet.*.id, count.index)}"
  route_table_id          = "${aws_route_table.csye6225_route_table.id}"
}

//CREATING APP SECURITY GROUP   ---> FROM ANYWHERE IN THE WORLD
resource "aws_security_group" "application"{

    name                = "application"
    description         = "App Security Group"
    vpc_id              = "${aws_vpc.csye6225_awsdev.id}" 

    ingress {
        description = "TLS from VPC"
        from_port   = 443
        to_port     = 443
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        description = "HTTP REQUEST from VPC"
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        description = "SSH from VPC"
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
  ingress {
        description = "FOR NODE REQUEST "
        from_port   = 3301
        to_port     = 3301
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
  ingress {
        description = "FOR ANGULAR PORT"
        from_port   = 4200
        to_port     = 4200
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
}
}

//CREATING DB SECURITY GROUP   ------> SOURCE OF TRAFFIC SHOUDL BE APPLICATION SECURITY GROUP
resource "aws_security_group" "database"{

    name                    = "database"
    description             = "DB Security Group"
    vpc_id                  = "${aws_vpc.csye6225_awsdev.id}" 

    ingress {
        description = "FOR MYSQL REQUEST "
        from_port   = 3306
        to_port     = 3306
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
        security_groups = ["${aws_security_group.application.id}"]
        
    }
    egress {
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
}
}


resource "aws_kms_key" "mykey" {
  description                       = "This key is used to encrypt bucket objects"
  deletion_window_in_days           = 10
}

//CREATING S3 BUCKET
resource "aws_s3_bucket" "S3_Bucket" {
    bucket          = "${var.bucket_name}"
    acl             = "private"
    force_destroy   = true


    lifecycle_rule {
        enabled = true
        transition {
            days = 30
            storage_class = "STANDARD_IA"
        }
    }
    server_side_encryption_configuration {
        rule {
        apply_server_side_encryption_by_default {
            //kms_master_key_id = "${aws_kms_key.mykey.arn}"
            sse_algorithm     = "AES256"
        }
        }
    }
}

resource "aws_s3_bucket_public_access_block" "s3_bucket_public_access_block" {

        bucket = "${aws_s3_bucket.S3_Bucket.id}"

        block_public_acls   = true
        block_public_policy = false
}

//CREATING RDS BD SUBNET GROUP
resource "aws_db_subnet_group" "db_subnet_group" {

  name        = "rds_subnet_group"
  //description = "Terraform example RDS subnet group"
  
  subnet_ids  = "${aws_subnet.csye6225_subnet.*.id}"
  tags ={
    
    Name = "My DB subnet group"
  }
}

//CREATING RDS INSTANCE
resource "aws_db_instance" "rds_instance"{
    allocated_storage           = "20"
    
    engine                      = "${var.db_engine}"
    instance_class              = "db.t3.micro"
    multi_az                    = false
    identifier                  = "${var.db_instance_identifier}"
    username                    = "${var.db_username}"
    password                    = "${var.db_password}"
    vpc_security_group_ids      = ["${aws_security_group.database.id}"]
    db_subnet_group_name        = "${aws_db_subnet_group.db_subnet_group.id}"
    publicly_accessible         = "false"
    name                        = "${var.db_name}"

    //final_snapshot_identifier   = true
    skip_final_snapshot         = true
    deletion_protection         = false
    delete_automated_backups    = true

}

//CREATING DYNAMO_DB TABLE
resource "aws_dynamodb_table" "dynamodb_table" {
    name           = "${var.dynamodb_table_name}"
    
    billing_mode   = "PROVISIONED"
    read_capacity  = 20
    write_capacity = 20
    hash_key       = "id"
    attribute {
        name = "id"
        type = "S"
    }   
}



//CREATING IAM ROLE
resource "aws_iam_role" "iam_role" {
  name = "EC2-CSYE6225"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

  tags = {
      tag-key = "tag-value"
  }
}
//CREATING IAM POLICY   -----------> replace *
resource "aws_iam_role_policy" "iam_role_policy" {
  name = "EC2-CSYE6225"
  role = "${aws_iam_role.iam_role.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:*"
      ],
      "Resource": [
        "arn:aws:s3:::webapp.jayesh.raghuwanshi",
        "arn:aws:s3:::webapp.jayesh.raghuwanshi/*"
      ]
    }
  ]
}
EOF
}


resource "aws_iam_instance_profile" "EC2-CSYE6225" {
  name = "EC2-CSYE6225"
  role = "${aws_iam_role.iam_role.name}"
}
data "aws_db_instance" "databaseData" {
  db_instance_identifier = "${aws_db_instance.rds_instance.id}"
 }


data "template_file" "init" {
  template = "${file("init.tpl")}"
  vars = {
    consul_address = "${data.aws_db_instance.databaseData.address}"
  }
}

//CREATING EC2 INSTANCE  ------> take variable from command line
resource "aws_instance" "web"{
    ami                             = "${var.ami_id}"
    count                           = "${length(data.aws_availability_zones.availability_zones.names)}"  
    subnet_id                       = "${element(aws_subnet.csye6225_subnet.*.id, count.index)}"
    associate_public_ip_address     = true
    instance_type                   = "t2.micro"
    //disable_api_termination         = true
    iam_instance_profile            = "${aws_iam_instance_profile.EC2-CSYE6225.name}"
    vpc_security_group_ids          = ["${aws_security_group.application.id}"]
    key_name                        = "${var.ssh-key-name}"
    
    user_data                       =     "${file("init.tpl")}"


    root_block_device {
    volume_size           = "20"
    volume_type           = "gp2"
    delete_on_termination = true
  }
}

/*
/


//CREATING IAM POLICY   -----------> replace *
resource "aws_iam_policy" "iam_policy"{
    name        = "WebAppS3"
    policy      = "${data.aws_iam_policy_document.iam_policy_document.json}"

}
//CREATING IAM ROLE
resource "aws_iam_role" "iam_role" {
    name               = "EC2-CSYE6225"
    assume_role_policy = "${aws_iam_policy.iam_policy.id}"

}
*/