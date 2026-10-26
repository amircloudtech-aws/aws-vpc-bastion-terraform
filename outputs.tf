output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}

output "security_group_ids" {
  value = {
    bastion = aws_security_group.bastion.id
    alb     = aws_security_group.alb.id
    app     = aws_security_group.app.id
  }
}

output "ssh_bastion" {
  value = "ssh -i ~/.ssh/${var.key_name}.pem ec2-user@${aws_instance.bastion.public_ip}"
}

output "ssh_private_template" {
  value = "ssh -i ~/.ssh/${var.key_name}.pem -J ec2-user@${aws_instance.bastion.public_ip} ec2-user@PRIVATE_IP"
}

output "alb_url" {
  description = "Open this in your browser"
  value       = "http://${aws_lb.app.dns_name}"
}
