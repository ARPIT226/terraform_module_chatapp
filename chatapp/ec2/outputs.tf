output "nginx_public_ip" {
  value = aws_instance.nginx_tf.public_ip
}

output "backend_private_ip" {
  value = aws_instance.backend_tf.private_ip
}

output "mysql_private_ip" {
  value = aws_instance.mysql_tf.private_ip
}

output "key_name" {
  value = aws_key_pair.mykey_tf.key_name
}
