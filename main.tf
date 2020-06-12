provider "aws"{
    region = "us-east-1"
}

resource "aws_vpc" "csye6225_awsdev"{
    cidr_block  = "10.0.0.0/16"
    enable_dns_hostnames = true
    enable_dns_support = true
    enable_classiclink_dns_support = true
    assign_generated_ipv6_cidr_block = false

    tags={
        Name = "csye6225_awsdev"
    }
}

resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = "${aws_vpc.csye6225_awsdev.id}"

  tags ={
      Name = "Internet_Gateway"
  }
}
variable "availability_zones"{
    default = ["us-east-1a","us-east-1b","us-east-1c"]
    type = "list"
}
variable "subnet_cidrs" {
  description = "Subnet CIDRs for public subnets (length must match configured availability_zones)"
  default = ["10.0.2.0/24","10.0.1.0/24","10.0.0.0/28"]
  type = "list"
}

resource "aws_subnet" "csye6225_subnet" {
  count = "${length(var.subnet_cidrs)}"
    
  vpc_id = "${aws_vpc.csye6225_awsdev.id}"
  cidr_block = "${var.subnet_cidrs[count.index]}"
  availability_zone = "${var.availability_zones[count.index]}"
}


resource "aws_route_table" "csye6225_route_table" {
  vpc_id = "${aws_vpc.csye6225_awsdev.id}"

  
}

resource "aws_route_table_association" "csye6225_route_table_association" {
  count = "${length(var.subnet_cidrs)}"

  subnet_id      = "${element(aws_subnet.csye6225_subnet.*.id, count.index)}"
  route_table_id = "${aws_route_table.csye6225_route_table.id}"
}