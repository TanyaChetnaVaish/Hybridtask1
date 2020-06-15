#SETTING PROFILE
provider "aws" {
  region = "ap-south-1"
  profile = "mytanya1"
}
#Creating SECURITY GROUP
resource "aws_security_group" "allow_tls" {
  name = "Security_01"
  description ="Allow SSH & HTTP inbound traffic"
  ingress {
    description = "Allowing HTTP"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
   ingress {
	description = "Allowing SSH"
        from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
egress {
	from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
tags = {
 Name = "Security_01"
}
}


#CREATING INSTANCE
resource "aws_instance" "tweb" {
depends_on = [aws_security_group.allow_tls,
]
  ami       = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name = "mykey11"
  security_groups = [ "Security_01" ]

  connection {
    type = "ssh"
    user = "ec2-user"
    private_key = file("C:/Users/TANYA/Downloads/mykey11.pem")
    host = aws_instance.tweb.public_ip
  }
#DOWNLOADING DEPENDENCIES AND CONFIGURING WEBSERVER
  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  }
  tags = {
    Name = "tanyaos1"
  }
}


#CREATING VOLUME
resource "aws_ebs_volume" "tebs" {
  availability_zone = aws_instance.tweb.availability_zone
  size = 1
  tags = {
    Name = "tanyaebs"
 }
}

#MOUNTING VOLUME 
resource "aws_volume_attachment" "tebs_att" {
  device_name = "/dev/sdh"
  volume_id = "${aws_ebs_volume.tebs.id}"
  instance_id = "${aws_instance.tweb.id}"
  force_detach =true
}
#PRINTING SYSTEM IP
output "myos_ip" {
  value = aws_instance.tweb.public_ip
}
resource "null_resource" "nulllocal2" {
        provisioner "local-exec" {
             command = "echo ${aws_instance.tweb.public_ip} > publicip.txt"
       }
}
#MOUTNING VOLUME AND CREATING PARTITION ,ALSO COPYING CODE FROM GITHUB INTO /VAR/WWW/HTML LOCATION
resource "null_resource" "nullremote3" {
depends_on = [
    aws_volume_attachment.tebs_att,
  ]
 connection {
   type = "ssh"
   user  = "ec2-user"
   private_key = file("C:/Users/TANYA/Downloads/mykey11.pem")
   host = aws_instance.tweb.public_ip
 }
provisioner "remote-exec" {
   inline = [
    "sudo mkfs.ext4 /dev/xvdh",
    "sudo mount /dev/xvdh /var/www/html",
    "sudo rm -rf /var/www/html/*",
    "sudo git clone https://github.com/TanyaChetnaVaish/Hybridtask1.git /var/www/html/"
   ]
}
}

#CREATING BUCKET
resource "aws_s3_bucket" "tanyab" {
  
  acl    = "public-read"
versioning {
enabled = true
}
}

#ADDING OBJECT TO THE BUCKET
resource "aws_s3_bucket_object" "bucketObject" {
bucket = aws_s3_bucket.tanyab.bucket
key = "download"
acl = "public-read"
source = "C:/Users/TANYA/Downloads/Photo/download.png"
etag = filemd5("C:/Users/TANYA/Downloads/Photo/download.png")
tags = {
  Name = "My_bucket"
  Environment = "Dev"
}
}

#CREATING CLOUD DISTRIBUTION USING S3 BUCKET  ORIGIN
resource "aws_cloudfront_distribution" "s3_distribution" {
depends_on = [ null_resource.nullremote3,
]

origin {
domain_name = "${aws_s3_bucket.tanyab.bucket_regional_domain_name}"
origin_id   = "my_first_origin"

}
enabled             = true
is_ipv6_enabled     = true
comment             = "Tanya Access Identity"
default_root_object = "download"
default_cache_behavior {
allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
cached_methods   = ["GET", "HEAD"]
target_origin_id = "my_first_origin"
forwarded_values {
query_string = false
cookies {
forward = "none"
}
}
viewer_protocol_policy = "allow-all"
min_ttl                = 0
default_ttl            = 3600
max_ttl                = 86400
}
#Cache behavior with precendence 0
ordered_cache_behavior {
path_pattern     = "/content/immutable/*"
allowed_methods  = ["GET", "HEAD", "OPTIONS"]
cached_methods   = ["GET", "HEAD", "OPTIONS"]
target_origin_id = "my_first_origin"
forwarded_values {
query_string = false
headers      = ["Origin"]
cookies {
forward = "none"
}
}
min_ttl                = 0
default_ttl            = 86400
max_ttl                = 31536000
compress               = true
viewer_protocol_policy = "redirect-to-https"
}
# Cache behavior with precedence 1
ordered_cache_behavior {
path_pattern     = "/content/*"
allowed_methods  = ["GET", "HEAD", "OPTIONS"]
cached_methods   = ["GET", "HEAD"]
target_origin_id = "my_first_origin"
forwarded_values {
query_string = false
cookies {
forward = "none"
}
}
min_ttl                = 0
default_ttl            = 3600
max_ttl                = 86400
compress               = true
viewer_protocol_policy = "redirect-to-https"
}
price_class = "PriceClass_200"
#PUTTING RESTRICTIONS
restrictions {
geo_restriction {
restriction_type = "whitelist"
locations        = ["CA","US","GB","IN"]
}
}
tags = {
Environment = "production"
}
viewer_certificate {
cloudfront_default_certificate = true
}
#ADDING THE CLOUDFRONT URL TO THE INDEX.HTML FILE AND THUS RUNNING THE PAGE
connection {
        type    = "ssh"
        user    = "ec2-user"
        private_key = file("C:/Users/TANYA/Downloads/mykey11.pem")
    	host     = aws_instance.tweb.public_ip
    }

provisioner "remote-exec" {
        inline  = [
            
            "sudo su << EOF",
            "echo \"<center><img src='http://${self.domain_name}/${aws_s3_bucket_object.bucketObject.key}' height='400' width='400'></center>\" >> /var/www/html/index.html",
            "EOF"
        ]
    }
#Showing Website
provisioner "local-exec" {
command = "start chrome ${aws_instance.tweb.public_ip}"
}


}






