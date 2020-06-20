data "aws_availability_zones" "availability_zones" {}
data "aws_iam_policy_document" "iam_policy_document"{
  /*  
    statement {
                "Action": [
                    "s3:*"
                ],
                "Effect": "Allow",
                "Resource": [
                    "arn:aws:s3:::YOUR_BUCKET_NAME",
                    "arn:aws:s3:::YOUR_BUCKET_NAME/*"
                ]
    }
    
}*/
  statement  {
                              
                    actions = ["s3:*"]
                    effect= "Allow"
                    resources = [
                    "arn:aws:s3:::webapp.jayesh.raghuwanshi",
                    "arn:aws:s3:::webapp.jayesh.raghuwanshi/*"
                    ]
                
            }


}