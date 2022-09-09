resource "aws_acm_certificate" "vpn_server" {
  domain_name = local.domain
  validation_method = "DNS"

  tags = local.global_tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate_validation" "vpn_server" {
  certificate_arn = aws_acm_certificate.vpn_server.arn

  timeouts {
    create = "20m"
  }
}

resource "aws_acm_certificate" "vpn_client_root" {
  private_key = file("certs/client-vpn-ca.key")
  certificate_body = file("certs/client-vpn-ca.crt")
  certificate_chain = file("certs/ca-chain.crt")

  tags = local.global_tags
}

resource "aws_security_group" "vpn_access" {
  vpc_id = aws_vpc.main.id
  name = "vpn-sg"

  ingress {
    from_port = 0
    protocol = "-1"
    to_port = 0
    cidr_blocks = [
      "0.0.0.0/0"]
  }

  egress {
    from_port = 0
    protocol = "-1"
    to_port = 0
    cidr_blocks = [
      "0.0.0.0/0"]
  }

  tags = local.global_tags
}

resource "aws_ec2_client_vpn_endpoint" "vpn" {
  description = "Client VPN"
  client_cidr_block = "10.20.0.0/22"
  split_tunnel = false
  server_certificate_arn = aws_acm_certificate_validation.vpn_server.certificate_arn
  security_group_ids = [aws_security_group.vpn_access.id]
  vpc_id = aws_vpc.main.id

  authentication_options {
    type = "certificate-authentication"
    root_certificate_chain_arn = aws_acm_certificate.vpn_client_root.arn
  }

  connection_log_options {
    enabled = false
  }

  tags = local.global_tags
}

resource "aws_ec2_client_vpn_network_association" "vpn_subnets" {
  count = length(aws_subnet.sn_az)

  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.vpn.id
  subnet_id = aws_subnet.sn_az[count.index].id
  # security_groups = [aws_security_group.vpn_access.id]

  lifecycle {
    ignore_changes = [subnet_id]
  }
}

resource "aws_ec2_client_vpn_route" "vpn_route" {
  count = length(aws_subnet.sn_az)

  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.vpn.id
  destination_cidr_block = "0.0.0.0/0"
  target_vpc_subnet_id   = aws_ec2_client_vpn_network_association.vpn_subnets[count.index].subnet_id
}

resource "aws_ec2_client_vpn_authorization_rule" "vpn_vpc_auth_rule" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.vpn.id
  target_network_cidr = aws_vpc.main.cidr_block
  authorize_all_groups = true
}

resource "aws_ec2_client_vpn_authorization_rule" "vpn_internet_auth_rule" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.vpn.id
  target_network_cidr = "0.0.0.0/0"
  authorize_all_groups = true
}
