output "shared_test_private_ip" {
  description = "Private IP of the shared-services test EC2"
  value       = aws_instance.shared_test.private_ip
}

output "prod_test_private_ip" {
  description = "Private IP of the prod test EC2"
  value       = aws_instance.prod_test.private_ip
}

output "dev_test_private_ip" {
  description = "Private IP of the dev test EC2"
  value       = aws_instance.dev_test.private_ip
}

output "peering_shared_prod_id" {
  description = "VPC Peering connection ID: shared ↔ prod"
  value       = aws_vpc_peering_connection.shared_prod.id
}

output "peering_shared_dev_id" {
  description = "VPC Peering connection ID: shared ↔ dev"
  value       = aws_vpc_peering_connection.shared_dev.id
}

output "verification_commands" {
  description = "Commands to verify segmentation — run from prod_test instance"
  value = {
    "prod_to_shared (should succeed)" = "ping ${aws_instance.shared_test.private_ip}"
    "prod_to_dev (should FAIL)"       = "ping ${aws_instance.dev_test.private_ip}"
    "dev_to_shared (should succeed)"  = "ping ${aws_instance.shared_test.private_ip}"
    "dev_to_prod (should FAIL)"       = "ping ${aws_instance.prod_test.private_ip}"
  }
}
