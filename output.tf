output "image-details" {
  value = data.aws_ami.ubuntu
}

output "lb-dns"{
  value = aws_elb.elb.dns_name
}