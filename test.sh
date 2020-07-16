#!/bin/bash
echo export RDS_HOSTNAME = 
sudo echo RDS_HOSTNAME = "${aws_db_instance.rds_instance.address}" | sudo tee -a /etc/environment