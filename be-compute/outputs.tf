output "be_instances_private_key" {
  description = "Private key for SSH access"
  value       = tls_private_key.be_keypair.private_key_openssh
  sensitive   = true
}
# terraform output -raw be_instances_private_key > be-sshkey.pem
# chmod 400 be-sshkey.pem

output "backend_public_instance_public_ip" {
  description = "Public (Elastic) IP of the backend public instance"
  value       = aws_eip.backend_public_instance_eip.public_ip
}

output "backend_public_instance_public_dns" {
  description = "Public DNS of the backend public instance"
  value       = aws_eip.backend_public_instance_eip.public_dns
}

output "backend_private_instance01_private_ip" {
  value = aws_instance.backend_private_instance01.private_ip
}

output "backend_private_instance02_private_ip" {
  value = aws_instance.backend_private_instance02.private_ip
}

output "backend_private_instance03_private_ip" {
  value = aws_instance.backend_private_instance03.private_ip
}
