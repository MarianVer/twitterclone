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

resource "docker_network" "jenkins_net" {
  name = "jenkins-network"
  driver = "bridge"
}

resource "docker_image" "jenkins_master" {
  name = "jenkins/jenkins:lts-jdk17"
}

resource "docker_container" "jenkins_master" {
  name  = "jenkins-master"
  image = docker_image.jenkins_master.image_id
  
  networks_advanced {
    name = docker_network.jenkins_net.name
  }
  
  # АВТОМАТИЧНИЙ ВИБІР ПОРТУ (0 = Docker вибере вільний)
  ports {
    internal = 8080
    external = 0
  }
  
  volumes {
    host_path      = "/home/acer/jenkins_home"
    container_path = "/var/jenkins_home"
  }

  restart = "unless-stopped"
}

resource "docker_image" "jenkins_agent" {
  name = "jenkins/inbound-agent:jdk17"
}

resource "docker_container" "jenkins_agent" {
  name  = "jenkins-agent"
  image = docker_image.jenkins_agent.image_id
  
  networks_advanced {
    name = docker_network.jenkins_net.name
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

  restart = "unless-stopped"
  depends_on = [docker_container.jenkins_master]
}

variable "jenkins_secret" {
  description = "Secret from Jenkins UI"
  type        = string
}

# Output для отримання реального порту
output "jenkins_url" {
  value = "http://localhost:${docker_container.jenkins_master.ports[0].external}"
}
