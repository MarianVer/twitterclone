terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0.0"
    }
    null = {
      source = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

provider "docker" {
  host = "unix:///var/run/docker.sock"
}

# Простий cleanup без sudo
resource "null_resource" "cleanup" {
  provisioner "local-exec" {
    command = <<-EOT
      # Просте очищення без sudo
      docker rm -f jenkins-master jenkins-agent 2>/dev/null || true
      docker network rm jenkins-network 2>/dev/null || true
      pkill -f "jenkins" || true
    EOT
    on_failure = continue  # Продовжити навіть якщо cleanup не вдасться
  }
}

# Мережа
resource "docker_network" "jenkins_net" {
  name    = "jenkins-network"
  driver  = "bridge"
  
  # Запобігає перестворенню мережі при оновленні
  lifecycle {
    create_before_destroy = true
    prevent_destroy       = false  # Дозволяє видаляти, але не випадково
  }
  
  # Додаткові налаштування для стабільності
  options = {
    com.docker.network.bridge.name = "jenkins-bridge"
  }
  
  labels = {
    environment = "production"
    managed-by  = "terraform"
  }
}

# База даних (додайте якщо є)
resource "docker_container" "database" {
  name  = "jenkins-db"
  image = "postgres:13"
  
  networks_advanced {
    name = docker_network.jenkins_net.name
  }
  
  env = [
    "POSTGRES_DB=jenkins",
    "POSTGRES_USER=jenkins",
    "POSTGRES_PASSWORD=your_password"
  ]
  
  volumes {
    host_path      = "/home/acer/jenkins_db_data"
    container_path = "/var/lib/postgresql/data"
  }

  # Життєвий цикл - запобігає перестворенню без потреби
  lifecycle {
    ignore_changes = [
      image,  # Не перестворювати при оновленні образу
      networks_advanced  # Не чіпати мережу
    ]
  }
  
  restart = "unless-stopped"
}

# Jenkins Master з оптимізацією
resource "docker_container" "jenkins_master" {
  name  = "jenkins-master"
  image = docker_image.jenkins_master.image_id
  
  networks_advanced {
    name    = docker_network.jenkins_net.name
    aliases = ["jenkins-master"]
  }
  
  ports {
    internal = 8080
    external = 8080  # Фіксований порт для стабільності
  }
  
  volumes {
    host_path      = "/home/acer/jenkins_home"
    container_path = "/var/jenkins_home"
  }

  # Життєвий цикл - запобігає перестворенню
  lifecycle {
    ignore_changes = [
      image,
      networks_advanced,
      ports  # Не змінювати порти після створення
    ]
  }
  
  restart = "unless-stopped"
  depends_on = [docker_container.database]  # Чекає на БД
}

# Jenkins Master
resource "docker_image" "jenkins_master" {
  name = "jenkins/jenkins:lts-jdk17"
}

resource "docker_container" "jenkins_master" {
  name  = "jenkins-master"
  image = docker_image.jenkins_master.image_id
  
  networks_advanced {
    name    = docker_network.jenkins_net.name
    aliases = ["jenkins-master"]
  }
  
  # Динамічний порт (Docker сам вибере вільний)
  ports {
    internal = 8080
    external = 0
  }
  
  volumes {
    host_path      = "/home/acer/jenkins_home"
    container_path = "/var/jenkins_home"
  }

  restart = "unless-stopped"
  
  depends_on = [null_resource.cleanup]
}

# Jenkins Agent
resource "docker_image" "jenkins_agent" {
  name = "jenkins/inbound-agent:jdk17"
}

resource "docker_container" "jenkins_agent" {
  name  = "jenkins-agent"
  image = docker_image.jenkins_agent.image_id
  
  networks_advanced {
    name    = docker_network.jenkins_net.name
    aliases = ["jenkins-agent"]
  }
  
  env = [
    "JENKINS_URL=http://jenkins-master:8080",
    "JENKINS_SECRET=${var.jenkins_secret}",
    "JENKINS_AGENT_NAME=docker-agent",
    "JENKINS_WEB_SOCKET=true"
  ]
  
  volumes {
    host_path      = "/var/run/docker.sock"
    container_path = "/var/run/docker.sock"
  }

  restart = "always"
  depends_on = [docker_container.jenkins_master]
}

variable "jenkins_secret" {
  description = "Secret from Jenkins UI"
  type        = string
  sensitive   = true
}

output "jenkins_url" {
  value = "http://localhost:${docker_container.jenkins_master.ports[0].external}"
}
