terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0.2"
    }
  }
}

provider "docker" {}

resource "docker_network" "jenkins" {
  name = "jenkins"
}

resource "docker_volume" "jenkins_docker_certs" {
  name = "jenkins-docker-certs"
}

resource "docker_volume" "jenkins_data" {
  name = "jenkins-data"
}

resource "docker_container" "jenkins_docker" {
  image = "docker:dind"
  name  = "jenkins-docker"
  restart = "no"
  must_run = true
  privileged = true
  networks_advanced {
    name    = docker_network.jenkins.name
    aliases = ["docker"]
  }
  env = ["DOCKER_TLS_CERTDIR=/certs"]
  volumes {
    volume_name    = "jenkins-docker-certs"
    container_path = "/certs/client"
  }
  volumes {
    volume_name    = "jenkins-data"
    container_path = "/var/jenkins_home"
  }
  ports {
    internal = 2376
    external = 2376
  }
  command = ["--storage-driver", "overlay2"]

  
}

resource "docker_container" "jenkins_blueocean" {
  image = "myjenkins-blueocean"
  name  = "jenkins-blueocean"
  restart = "on-failure"
  must_run = true
  networks_advanced {
    name    = docker_network.jenkins.name
  }
  env = [
    "DOCKER_HOST=tcp://docker:2376",
    "DOCKER_CERT_PATH=/certs/client",
    "DOCKER_TLS_VERIFY=1"
  ]
  volumes {
    volume_name    = "jenkins-data"
    container_path = "/var/jenkins_home"
  }
  volumes {
    volume_name    = "jenkins-docker-certs"
    container_path = "/certs/client"
    read_only      = true
  }
  ports {
    internal = 8080
    external = 8080
  }
  ports {
    internal = 50000
    external = 50000
  }

  
}

