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
        description = "Nginx server"
        from_port   = 8080
        to_port     = 8080
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
        cidr_blocks = [aws_vpc.csye6225_awsdev.cidr_block]
        security_groups = ["${aws_security_group.application.id}"]
        
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

        block_public_acls   = false
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

//Creating JSON for Circle to S3 policy    --->>>>>> 2 POLICY
data "aws_iam_policy_document" "CircleCI_To_S3" {
  statement {
    actions   = [
                "s3:PutObject",
                "s3:Get*",
                "s3:List*"
                ]
    resources = [
                  "arn:aws:s3:::codedeploy.potterheadsbookstore.me",
                  "arn:aws:s3:::codedeploy.potterheadsbookstore.me/*"
                  ]
  }
}

//CircleCI-Upload-To-S3 Policy for CircleCI to Upload to AWS S3      ----->> 2 POLICY
resource "aws_iam_policy" "CircleCI_Upload_To_S3"{
    name        = "CircleCI_Upload_To_S3"
    policy = "${data.aws_iam_policy_document.CircleCI_To_S3.json}"
    
}

//Attaching policy to user CICD   -                     --->> 2 POLICY ATTACHED TO USER CICD
resource "aws_iam_user_policy_attachment" "cicd_CircleCI-Upload-To-S3" {
  user       = "cicd"
  policy_arn = "${aws_iam_policy.CircleCI_Upload_To_S3.arn}"
}

//Creating JSON for Circle CI CodeDeploy          -------->>  3 POLICY JSON
data "aws_iam_policy_document" "CircleCI_CodeDeploy" {

statement {
  actions   = [
        "codedeploy:RegisterApplicationRevision",
        "codedeploy:GetApplicationRevision"]
  resources = ["arn:aws:codedeploy:${var.region}:${var.aws_account_id}:application:${var.code_deploy_application_name}"
  ]
}

statement {
  actions = [
        "codedeploy:CreateDeployment",
        "codedeploy:GetDeployment"
  ]
  resources = ["arn:aws:codedeploy:${var.region}:${var.aws_account_id}:application:${var.code_deploy_application_name}",
    "arn:aws:codedeploy:${var.region}:${var.aws_account_id}:deploymentgroup:${var.code_deploy_application_name}/csye6225-webapp-deployment"

  ]

}
statement{

  actions = ["codedeploy:GetDeploymentConfig"]
  resources = [
              "arn:aws:codedeploy:${var.region}:${var.aws_account_id}:deploymentconfig:CodeDeployDefault.OneAtATime",
              "arn:aws:codedeploy:${var.region}:${var.aws_account_id}:deploymentconfig:CodeDeployDefault.HalfAtATime",
              "arn:aws:codedeploy:${var.region}:${var.aws_account_id}:deploymentconfig:CodeDeployDefault.AllAtOnce"
        ]
}

}



//CircleCI-Code-Deploy Policy for CircleCI to Call CodeDeploy      ---------->> 3 POLICY
resource "aws_iam_policy" "CircleCI_Code_Deploy"{

    name        = "CircleCI-Code-Deploy"
    policy      = "${data.aws_iam_policy_document.CircleCI_CodeDeploy.json}"
   
}



//Attaching policy to user CICD                              -------->>> ATTACHING 3 POLICY to CICD USER
resource "aws_iam_user_policy_attachment" "cicd_CircleCI-Code-Deploy" {
  user       = "cicd"
  policy_arn = "${aws_iam_policy.CircleCI_Code_Deploy.arn}"
}



//Creating role CodeDeploy EC2 Service Role to attach to EC2 instance     ------->> 1 POLICY ROLE
resource "aws_iam_role" "CodeDeployEC2ServiceRole" {
  
  name = "CodeDeployEC2ServiceRole"

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
}

//CREATING IAM POLICY TO ATTACH TO EC2 INSTANCE
resource "aws_iam_role_policy" "iam_role_policy" {
  name = "EC2-CSYE6225"
  role = "${aws_iam_role.CodeDeployEC2ServiceRole.id}"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "s3:Put*",
                "s3:Get*",
                "s3:Delete*",
                "s3:Create*",
                "s3:Replicate*",
                "s3:List*",
                "s3:Abort*",
                "s3:Update*"
               
            ],
            "Resource": [
               "arn:aws:s3:::webapp.jayeshr",
              "arn:aws:s3:::webapp.jayeshr/*"
            ]
        },
        {
            "Sid": "VisualEditor1",
            "Effect": "Allow",
            "Action": [
                "s3:Get*",
                "s3:Put*",
                "s3:Get*",
                "s3:List*",
                "s3:Create*",
                "s3:Head*"
            ],
            "Resource": [
              "arn:aws:s3:::webapp.jayeshr",
              "arn:aws:s3:::webapp.jayeshr/*"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_role_policy" "iam_role_policy_2" {
  name = "EC2-CSYE6225-CodeDeplyBucket"
  role = "${aws_iam_role.CodeDeployEC2ServiceRole.id}"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "s3:Put*",
                "s3:Get*",
                "s3:Delete*",
                "s3:Create*",
                "s3:Replicate*",
                "s3:List*",
                "s3:Abort*",
                "s3:Update*"
               
            ],
            "Resource": [
               "arn:aws:s3:::codedeploy.potterheadsbookstore.me",
              "arn:aws:s3:::codedeploy.potterheadsbookstore.me/*"
            ]
        },
        {
            "Sid": "VisualEditor1",
            "Effect": "Allow",
            "Action": [
                "s3:Get*",
                "s3:Put*",
                "s3:Get*",
                "s3:List*",
                "s3:Create*",
                "s3:Head*"
            ],
            "Resource": [
              "arn:aws:s3:::codedeploy.potterheadsbookstore.me",
              "arn:aws:s3:::codedeploy.potterheadsbookstore.me/*"
            ]
        }
    ]
}
EOF
 
}



//CREATE CodeDeployServiceRole                     ------->> 2 ROLE
resource "aws_iam_role" "CodeDeployServiceRole" {
  name                        = "CodeDeployServiceRole"
  assume_role_policy          = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "codedeploy.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF 
  
  
  force_detach_policies = true
}

// ATTACHING ROLE 2 to POLICY                                ----->> ROLE 2 POLICY ATTACHMENT
resource "aws_iam_role_policy_attachment" "CodeDeployServiceRole_Attachment"{
  role = "${aws_iam_role.CodeDeployServiceRole.id}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
}

//Attaching policy 3 to role                                 ----------------->>> CloudWatchAgent Server policy
resource "aws_iam_role_policy_attachment" "CodeDeployServiceRole2_Attachment"{
  role = "${aws_iam_role.CodeDeployEC2ServiceRole.id}"
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}



resource "aws_iam_instance_profile" "CodeDeployEC2ServiceRole_Instance" {
  name = "CodeDeployEC2ServiceRole_Instance"
  role = "${aws_iam_role.CodeDeployEC2ServiceRole.name}"
}
//AWS EC2 INSTANCE
resource "aws_instance" "web" {

  ami                             = "${var.ami_id}"
  subnet_id                       = "${aws_subnet.csye6225_subnet[0].id}"
  associate_public_ip_address     = true
  instance_type                   = "t2.micro"
  key_name                        = "${var.ssh-key-name}"
  iam_instance_profile            = "${aws_iam_instance_profile.CodeDeployEC2ServiceRole_Instance.name}"
  vpc_security_group_ids          = ["${aws_security_group.application.id}"]

  tags ={
    Name = "ec2-instance"
  }
    user_data                       = "${file("init.tpl")}"
   
    root_block_device {
    volume_size           = "20"
    volume_type           = "gp2"
    delete_on_termination = true
  }
  depends_on = [aws_db_instance.rds_instance]

}
// CREATING CODE DEPLOY APP
resource "aws_codedeploy_app" "CodeDeploy_App" {
  compute_platform = "Server"
  name             = "csye6225-webapp"
}
//CREATING CODE DEPLOY DEPLOYMENT GROUP
resource "aws_codedeploy_deployment_group" "example" {
  app_name              = "${aws_codedeploy_app.CodeDeploy_App.name}"
  deployment_group_name = "csye6225-webapp-deployment"
  service_role_arn      = "${aws_iam_role.CodeDeployServiceRole.arn}"
  
  deployment_style {
    //deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "IN_PLACE"
  }

  ec2_tag_filter{
      key   = "Name"
      type  = "KEY_AND_VALUE"
      value = "ec2-instance"
  }

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }



}