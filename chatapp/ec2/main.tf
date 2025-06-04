resource "tls_private_key" "mykey" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "private_key" {
  content         = tls_private_key.mykey.private_key_pem
  filename        = "${path.module}/mykey_tf.pem"
  file_permission = "0400"
}

resource "aws_key_pair" "mykey_tf" {
  key_name   = "mykey_tf"
  public_key = tls_private_key.mykey.public_key_openssh
}

# mysql database instance hai --------------------------------------

resource "aws_instance" "mysql_tf" {
  instance_type = "t2.micro"
  ami           = var.default_ubuntu_ami
  subnet_id     = var.private_subnet_id
  key_name      = aws_key_pair.mykey_tf.key_name
  associate_public_ip_address = false
  vpc_security_group_ids = [var.security_group_ids["mysql"]]

  tags = {
    Name = "mysql_tf"
  }

  provisioner "remote-exec" {
    inline = [
       "sudo apt update",
        "sudo apt install wget lsb-release gnupg -y",
        # Add MySQL APT repo manually
        "wget https://dev.mysql.com/get/mysql-apt-config_0.8.29-1_all.deb",
        "sudo DEBIAN_FRONTEND=noninteractive dpkg -i mysql-apt-config_0.8.29-1_all.deb",
        "sudo apt update",

        # Now install MySQL Server
        "sudo DEBIAN_FRONTEND=noninteractive apt install -y mysql-server",

        "sudo mysql -e \"CREATE DATABASE chatapp_db;\"",
        "sudo mysql -e \"CREATE USER 'arpit'@'%' IDENTIFIED BY 'Amazonrds25';\"",
        "sudo mysql -e \"GRANT ALL PRIVILEGES ON chatapp_db.* TO 'arpit'@'%';\"",
        "sudo mysql -e \"FLUSH PRIVILEGES;\""
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key= tls_private_key.mykey.private_key_pem
      host        = self.private_ip

      bastion_host        = aws_instance.nginx_tf.public_ip
      bastion_user        = "ubuntu"
      bastion_private_key = tls_private_key.mykey.private_key_pem
    }
  }

  depends_on = [null_resource.wait_for_nginx_for_database]
}

# Null resource to ensure nginx instance is ready before mysql provisioner runs

resource "null_resource" "wait_for_nginx_for_database" {
  depends_on = [aws_instance.nginx_tf]

  provisioner "local-exec" {
    command = "echo Nginx instance is ready, proceeding with MySQL instance provisioning"
  }
}

# backend instance (django) hai --------------------------------------

resource "aws_instance" "backend_tf" {
  instance_type = "t2.micro"
  ami = var.default_ubuntu_ami
  subnet_id = var.private_subnet_id
  key_name = aws_key_pair.mykey_tf.key_name
  associate_public_ip_address = false
  vpc_security_group_ids = [var.security_group_ids["django"]]

  tags = {
    Name = "backend_tf"
  }

  provisioner "remote-exec" {
    inline = [
        "sudo apt-get update",
        "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y software-properties-common git",

        "sudo add-apt-repository ppa:deadsnakes/ppa -y",
        "sudo apt-get update",
        "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y python3.8 python3.8-venv python3.8-distutils",
        "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y gcc python3.8-dev default-libmysqlclient-dev build-essential pkg-config",

        "sudo git clone https://github.com/ARPIT226/chat_app.git /chatapp",
        "sudo chown -R ubuntu:ubuntu /chatapp",

        "python3.8 -m venv /chatapp/venv",
        "/chatapp/venv/bin/pip install --upgrade pip",
        "/chatapp/venv/bin/pip install mysqlclient",
        "/chatapp/venv/bin/pip install gunicorn",
        "/chatapp/venv/bin/pip install -r /chatapp/requirements.txt",

        # Set krlo environment variables globally
        "echo 'DB_NAME=chatapp_db' | sudo tee -a /etc/environment",
        "echo 'DB_USER=arpit' | sudo tee -a /etc/environment",
        "echo 'DB_PASSWORD=Amazonrds25' | sudo tee -a /etc/environment",
        "echo 'DB_HOST=${aws_instance.mysql_tf.private_ip}' | sudo tee -a /etc/environment",
        "echo 'DB_PORT=3306' | sudo tee -a /etc/environment",

        # variables export krlo
        "export DB_NAME=chatapp_db",
        "export DB_USER=arpit",
        "export DB_PASSWORD=Amazonrds25",
        "export DB_HOST=${aws_instance.mysql_tf.private_ip}",
        "export DB_PORT=3306",

        # migrations bhi krna hai
        "cd /chatapp/fundoo && /chatapp/venv/bin/python manage.py makemigrations",
        "cd /chatapp/fundoo && /chatapp/venv/bin/python manage.py migrate",

        "sudo tee /etc/systemd/system/gunicorn.service > /dev/null <<EOF\n[Unit]\nDescription=Gunicorn service for Django app\nAfter=network.target\n\n[Service]\nUser=ubuntu\nGroup=ubuntu\nWorkingDirectory=/chatapp\nEnvironment=\"DB_NAME=chatapp_db\"\nEnvironment=\"DB_USER=arpit\"\nEnvironment=\"DB_PASSWORD=Amazonrds25\"\nEnvironment=\"DB_HOST=${aws_instance.mysql_tf.private_ip}\"\nEnvironment=\"DB_PORT=3306\"\nExecStart=/bin/bash -c \"cd /chatapp && source venv/bin/activate && cd /chatapp/fundoo && /chatapp/venv/bin/gunicorn --workers 3 --bind 0.0.0.0:8000 fundoo.wsgi:application\"\nRestart=always\n\n[Install]\nWantedBy=multi-user.target\nEOF",

        # Reload krlo systemd and start Django service
        "sudo systemctl daemon-reload",
        "sudo systemctl enable gunicorn",
        "sudo systemctl start gunicorn"

    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = tls_private_key.mykey.private_key_pem
      host        = self.private_ip

      bastion_host        = aws_instance.nginx_tf.public_ip
      bastion_user        = "ubuntu"
      bastion_private_key = tls_private_key.mykey.private_key_pem
    }
  }

  depends_on = [null_resource.wait_for_nginx_for_backend]
}

# Null resource to ensure nginx instance is ready before mysql provisioner runs

resource "null_resource" "wait_for_nginx_for_backend" {
  depends_on = [aws_instance.nginx_tf]

  provisioner "local-exec" {
    command = "echo Nginx instance is ready, proceeding with django instance provisioning"
  }
}


# frontent instance (nginx) hai --------------------------------------

resource "aws_instance" "nginx_tf" {
  instance_type               = "t2.micro"
  ami                        = var.default_ubuntu_ami
  subnet_id                  = var.public_subnet_id
  key_name                   = aws_key_pair.mykey_tf.key_name
  associate_public_ip_address = true
  vpc_security_group_ids     = [var.security_group_ids["nginx"]]

  tags = {
    Name = "nginx_tf"
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = tls_private_key.mykey.private_key_pem
    host        = self.public_ip
  }

  provisioner "file" {
    content     = tls_private_key.mykey.private_key_pem
    destination = "/home/ubuntu/mykey_tf.pem"
  }
}

resource "null_resource" "test_nginx_ssh_to_backend" {
  depends_on = [aws_instance.nginx_tf, aws_instance.backend_tf, aws_instance.mysql_tf]

  provisioner "remote-exec" {
    inline = [
        "chmod 400 /home/ubuntu/mykey_tf.pem",
        "ssh -o StrictHostKeyChecking=no -i /home/ubuntu/mykey_tf.pem ubuntu@${aws_instance.backend_tf.private_ip} 'echo Connected to Backend!'"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = tls_private_key.mykey.private_key_pem
      host        = aws_instance.nginx_tf.public_ip
    }
  }
}

resource "null_resource" "configure_nginx_after_backend" {
  depends_on = [aws_instance.backend_tf, aws_instance.nginx_tf]

  provisioner "remote-exec" {
    inline = [
        "sudo apt update",
        "sudo apt install nginx -y",
        "sudo bash -c 'echo \"server { listen 80; server_name _; location / { proxy_pass http://${aws_instance.backend_tf.private_ip}:8000; } }\" > /etc/nginx/sites-available/chat_app.conf'",
        "sudo rm -f /etc/nginx/sites-enabled/default",
        "sudo ln -s /etc/nginx/sites-available/chat_app.conf /etc/nginx/sites-enabled/",
        "sudo nginx -t",
        "sudo systemctl restart nginx"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = tls_private_key.mykey.private_key_pem
      host        = aws_instance.nginx_tf.public_ip
    }
  }
}