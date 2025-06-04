output "security_group_ids" {
  value = {
    nginx  = aws_security_group.nginx_sg_tf.id
    django = aws_security_group.django_sg_tf.id
    mysql  = aws_security_group.mysql_sg_tf.id
  }
}
