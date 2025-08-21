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
      docker rm -f jenkins-master jenkins-agent prometheus grafana 2>/dev/null || true
      docker network rm jenkins-network 2>/dev/null || true
      pkill -f "jenkins" || true
    EOT
    on_failure = continue
  }
}

# Мережа - ДОДАНО LIFECYCLE
resource "docker_network" "jenkins_net" {
  name    = "jenkins-network"
  driver  = "bridge"
  
  # ЗАВДАННЯ 3: запобігає перестворенню мережі
  lifecycle {
    create_before_destroy = true
    prevent_destroy       = false
  }
  
  depends_on = [null_resource.cleanup]
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
  
  ports {
    internal = 8080
    external = 0
  }
  
  volumes {
    host_path      = "/home/acer/jenkins_home"
    container_path = "/var/jenkins_home"
  }

  # ЗАВДАННЯ 3: запобігає перестворенню контейнера
  lifecycle {
    ignore_changes = [
      image,
      networks_advanced
    ]
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
  
  # ФІКС: Агент ПОВИНЕН бути в мережі!
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

  # ЗАВДАННЯ 3: запобігає перестворенню агента
  lifecycle {
    ignore_changes = [
      image,
      networks_advanced,
      env
    ]
  }

  restart = "always"
  depends_on = [docker_container.jenkins_master]
}

# Prometheus в основній мережі Jenkins
resource "docker_container" "prometheus" {
  name  = "prometheus"
  image = "prom/prometheus:latest"
  
  networks_advanced {
    name    = docker_network.jenkins_net.name
    aliases = ["prometheus"]
  }
  
  ports {
    internal = 9090
    external = 9090
  }
  
  volumes {
    host_path      = "/home/acer/prometheus"
    container_path = "/etc/prometheus"
  }
  
  restart = "unless-stopped"
}

# Grafana в основній мережі Jenkins  
resource "docker_container" "grafana" {
  name  = "grafana"
  image = "grafana/grafana-oss:latest"
  
  networks_advanced {
    name    = docker_network.jenkins_net.name
    aliases = ["grafana"]
  }
  
  ports {
    internal = 3000
    external = 3000
  }
  
  volumes {
    host_path      = "/home/acer/grafana"
    container_path = "/var/lib/grafana"
  }
  
  env = [
    "GF_SECURITY_ADMIN_PASSWORD=admin123"
  ]
  
  restart = "unless-stopped"
  depends_on = [docker_container.prometheus]
}

variable "jenkins_secret" {
  description = "Secret from Jenkins UI"
  type        = string
  sensitive   = true
}

output "jenkins_url" {
  value = "http://localhost:${docker_container.jenkins_master.ports[0].external}"
}

output "prometheus_url" {
  value = "http://localhost:9090"
}

output "grafana_url" {
  value = "http://localhost:3000"
}
