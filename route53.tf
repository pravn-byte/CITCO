resource "aws_route53_zone" "demo-zone" {
  name = "vishnudevops.com"
}

resource "aws_route53_record" "demo-record" {
  zone_id = aws_route53_zone.demo-zone.zone_id
  name    = "vishnudevops.com" # OR "www.example.com"
  type    = "A" # OR "AAAA"

  alias {
      name                   = aws_elb.elb.dns_name
      zone_id                = aws_elb.elb.zone_id
      evaluate_target_health = true
  }
}