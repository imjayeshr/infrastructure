data "aws_availability_zones" "availability_zones" {}
data "template_file" "init" {
  template = "${file("${path.module}/init.tpl")}"
  vars = {
    hostname = "${aws_db_instance.rds_instance.address}"
  }
}
