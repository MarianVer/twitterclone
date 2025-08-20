terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0.0"
    }
  }
}

provider "docker" {
  host = "unix:///var/run/docker.sock"
}

# Мережа з імпортом існуючого ресурсу
resource "docker_network" "jenkins_net" {
  name       = "jenkins-network"
  driver     = "bridge"
  attachable = true

  lifecycle {
    ignore_changes = [name]  # Ігнорувати конфлікти імен
  }
}

# Jenkins Master
resource "docker_image" "jenkins_master" {
  name         = "jenkins/jenkins:lts-jdk17"
  keep_locally = true
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
    external = 9080
  }
  
  ports {
    internal = 50000
    external = 50001
  }
  
  volumes {
    host_path      = "/home/acer/jenkins_home"
    container_path = "/var/jenkins_home"
  }

  restart = "unless-stopped"
  shm_size = 1073741824 # 1GB
  
  healthcheck {
    test     = ["CMD", "curl", "-f", "http://localhost:8080"]
    interval = "30s"
    timeout  = "10s"
    retries  = 5
  }
}

# Jenkins Agent
resource "docker_image" "jenkins_agent" {
  name         = "jenkins/inbound-agent:jdk17"
  keep_locally = true
}

resource "docker_container" "jenkins_agent" {
  name     = "jenkins-agent"
  image    = docker_image.jenkins_agent.image_id
  
  networks_advanced {
    name    = docker_network.jenkins_net.name
    aliases = ["jenkins-agent"]
  }
  
  env = [
    "JENKINS_URL=http://jenkins-master:8080",
    "JENKINS_SECRET=${var.jenkins_secret}",
    "JENKINS_AGENT_NAME=docker-agent",
    "JENKINS_WEB_SOCKET=true",
    "JENKINS_AGENT_WORKDIR=/home/jenkins/agent"
  ]
  
  volumes {
    host_path      = "/var/run/docker.sock"
    container_path = "/var/run/docker.sock"
  }
  
  volumes {
    host_path      = "/home/acer/jenkins_agent_workdir"
    container_path = "/home/jenkins/agent"
  }

  restart    = "on-failure"
  memory     = 2147483648 # 2GB
  cpu_shares = 512
  
  depends_on = [docker_container.jenkins_master]
}

variable "jenkins_secret" {
  description = "Agent connection secret from Jenkins UI"
  type        = string
  sensitive   = true
}
