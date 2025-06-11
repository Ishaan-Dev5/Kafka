output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_1_id" {
  description = "Public Subnet 1 ID"
  value       = aws_subnet.public_subnet_1.id
}

output "public_subnet_2_id" {
  description = "Public Subnet 2 ID"
  value       = aws_subnet.public_subnet_2.id
}

output "private_subnet_1_id" {
  description = "Private Subnet 1 ID"
  value       = aws_subnet.private_subnet_1.id
}

output "private_subnet_2_id" {
  description = "Private Subnet 2 ID"
  value       = aws_subnet.private_subnet_2.id
}

output "bastionhost_public_ip" {
  description = "Public IP of the bastion host"
  value       = aws_instance.instance.public_ip
}

output "private_instance_1_private_ip" {
  description = "Private IP of Kafka private instance 1"
  value       = aws_instance.private_instance_1.private_ip
}

output "private_instance_2_private_ip" {
  description = "Private IP of Kafka private instance 2"
  value       = aws_instance.private_instance_2.private_ip
}

output "kafka_nlb_dns_name" {
  description = "DNS name of the Kafka Network Load Balancer"
  value       = aws_lb.kafka_nlb.dns_name
}

output "kafka_nlb_target_group_arn" {
  description = "Kafka Target Group ARN"
  value       = aws_lb_target_group.kafka_tg.arn
}
