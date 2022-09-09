locals {
  region = "eu-west-2" # Location -> London
  global_tags = {
    "environment" = "aws-client-vpn"
  }
  domain = "vpn.example.com"
  availability_zones = sort(data.aws_availability_zones.available.names)
}