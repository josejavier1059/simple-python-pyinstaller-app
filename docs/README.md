# Entrega Practica 3
Jose Javier García Torrejón

Samuel Fernández Peinado

## Parte 1:

1. Primero creamos el archivo terraform llamado main.tf en el que definimos dos contenedores, uno con docker in docker ("jenkins-docker") y otro con jenkins ("myjenkins-blueocean"). Además también crearemos una red ("jenkins") para conectar los contenedores.
```hcl
# Configura el proveedor de Terraform para usar Docker.
terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0.2"
    }
  }
}

# Define el proveedor Docker.
provider "docker" {}

# Crea una red Docker llamada 'jenkins'. Los contenedores se conectarán a esta red.
resource "docker_network" "jenkins" {
  name = "jenkins"
}

# Define un volumen Docker para almacenar los certificados TLS utilizados por Docker-in-Docker.
resource "docker_volume" "jenkins_docker_certs" {
  name = "jenkins-docker-certs"
}

# Define otro volumen Docker para almacenar los datos de Jenkins.
resource "docker_volume" "jenkins_data" {
  name = "jenkins-data"
}

# Configura el contenedor Docker-in-Docker (DinD).
resource "docker_container" "jenkins_docker" {
  image = "docker:dind"  # Usa la imagen 'docker:dind'.
  name  = "jenkins-docker"  # Nombre del contenedor.
  restart = "no"  # Política de reinicio.
  must_run = true  # Asegura que el contenedor esté siempre en ejecución.
  privileged = true  # Modo privilegiado necesario para DinD.
  networks_advanced {  # Conexión avanzada a la red.
    name    = docker_network.jenkins.name
    aliases = ["docker"]  # Alias en la red.
  }
  env = ["DOCKER_TLS_CERTDIR=/certs"]  # Variable de entorno para TLS.
  volumes {  # Monta el volumen de certificados TLS.
    volume_name    = "jenkins-docker-certs"
    container_path = "/certs/client"
  }
  volumes {  # Monta el volumen de datos de Jenkins.
    volume_name    = "jenkins-data"
    container_path = "/var/jenkins_home"
  }
  ports {  # Expone el puerto 2376.
    internal = 2376
    external = 2376
  }
  command = ["--storage-driver", "overlay2"]  # Comando adicional para el contenedor.
}

# Configura el contenedor de Jenkins Blue Ocean.
resource "docker_container" "jenkins_blueocean" {
  image = "myjenkins-blueocean"  # Usa la imagen personalizada.
  name  = "jenkins-blueocean"  # Nombre del contenedor.
  restart = "on-failure"  # Política de reinicio.
  must_run = true  # Asegura que el contenedor esté siempre en ejecución.
  networks_advanced {  # Conexión a la red.
    name    = docker_network.jenkins.name
  }
  env = [  # Variables de entorno para la conexión Docker y configuración de Java.
    "DOCKER_HOST=tcp://docker:2376",
    "DOCKER_CERT_PATH=/certs/client",
    "DOCKER_TLS_VERIFY=1",
    "JAVA_OPTS=${var.JAVA_OPTS}"
  ]
  volumes {  # Monta los volúmenes necesarios para Jenkins.
    volume_name    = "jenkins-data"
    container_path = "/var/jenkins_home"
  }
  volumes {
    volume_name    = "jenkins-docker-certs"
    container_path = "/certs/client"
    read_only      = true
  }
  ports {  # Expone los puertos 8080 y 50000 para el acceso web y la comunicación del agente.
    internal = 8080
    external = 8080
  }
  ports {
    internal = 50000
    external = 50000
  }
}
```

2. Antes de aplicar este archifo terraform tenemos que crear la imagen de docker que estamos usando en el contenedor "docker-blueocean", para ello definimos el siguiente Dockerfile en el que cogemos la imagen de jenkins, le instalamos docker y el plugin de blueocean.
```dockerfile
FROM jenkins/jenkins:2.426.2-jdk17
USER root
RUN apt-get update && apt-get install -y lsb-release
RUN curl -fsSLo /usr/share/keyrings/docker-archive-keyring.asc \
  https://download.docker.com/linux/debian/gpg
RUN echo "deb [arch=$(dpkg --print-architecture) \
  signed-by=/usr/share/keyrings/docker-archive-keyring.asc] \
  https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
RUN apt-get update && apt-get install -y docker-ce-cli
USER jenkins
RUN jenkins-plugin-cli --plugins "blueocean:1.27.9 docker-workflow:572.v950f58993843"
```
Para construir la imagen nos movemos hasta el directorio en el que se encuentra el dockerfile y ejecutamos el comando para crearla 
```docker build -t myjenkins-blueocean . ```


3. Como ya tenemos nuestr imagen podremos aplicar el terraform, estando en el directorio de nuestro archivo .tf tenemos que prepararlo para aplicar el terrraform ejecutando
   ```terrafom init``` y posteriormente aplicamos el terraform con ```terrafom apply``` lo que nos creará los contenedores y la red.

4. Al entrar en nuestro navegador en localhost:8080 nos debe aparecer una pantalla como esta, para accede a jenkins debemos escribir este comando ```docker logs jenkins-blueocean``` y copiar los numeros que nos aparecen en la imagen para introducirlos en el campo donde nos lo solicitan, luego podremos crear un usuario de jenkins y acceder a la herramienta.
   
![Screenshot from 2023-12-18 00-49-25](https://github.com/josejavier1059/simple-python-pyinstaller-app/assets/86070772/30199410-3a33-46ed-9483-35f18e03fb43)

5. Una vez dentro de jenkins, le damos a crear nuevo recurso, le damos el nombre deseado y seleccionamos la opcion pipeline

![nombrepipeline](https://github.com/josejavier1059/mark/assets/72498118/d7ec839c-941a-457d-98ba-7243bcb1e4a8)

7. Elegimos la opción from SMC, metemos nuestro link al repositorio de git y en rama especificamos main.

![git](https://github.com/josejavier1059/mark/assets/72498118/20a30bc4-d2b1-418a-b591-15fabe892574)

8. Cabe destacar que debemos haber creado la rama main en github dandole a la opcion new branch
   
![branch](https://github.com/josejavier1059/mark/assets/72498118/f9ed6a99-87db-4eea-b405-745e164c9a61)

9. Abajo ponemos la ruta a nuestro Jenkinsfile

![jenkins,jenkinsfile](https://github.com/josejavier1059/mark/assets/72498118/0662c1b3-5291-423f-862e-718451ccde21)

10. El jenkinsfile lo hemos sacado del tutorial y es este:
   
```groovy
pipeline {
    agent none
    options {
        skipStagesAfterUnstable()
    }
    stages {
        stage('Build') {
            agent {
                docker {
                    image 'python:3.12.1-alpine3.19'
                }
            }
            steps {
                sh 'python -m py_compile sources/add2vals.py sources/calc.py'
                stash(name: 'compiled-results', includes: 'sources/*.py*')
            }
        }
        stage('Test') {
            agent {
                docker {
                    image 'qnib/pytest'
                }
            }
            steps {
                sh 'py.test --junit-xml test-reports/results.xml sources/test_calc.py'
            }
            post {
                always {
                    junit 'test-reports/results.xml'
                }
            }
        }
        stage('Deliver') { 
            agent any
            environment { 
                VOLUME = '$(pwd)/sources:/src'
                IMAGE = 'cdrx/pyinstaller-linux:python2'
            }
            steps {
                dir(path: env.BUILD_ID) { 
                    unstash(name: 'compiled-results') 
                    sh "docker run --rm -v ${VOLUME} ${IMAGE} 'pyinstaller -F add2vals.py'" 
                }
            }
            post {
                success {
                    archiveArtifacts "${env.BUILD_ID}/sources/dist/add2vals" 
                    sh "docker run --rm -v ${VOLUME} ${IMAGE} 'rm -rf build dist'"
                }
            }
        }
    }
}
```
11.Entramos en jenkins blueocean y le damos a iniciar
![le doy a iniciar](https://github.com/josejavier1059/mark/assets/72498118/d1d2ed93-a612-4126-9152-131ee07453b4)

12.Dejamos que suceda la magia(de magia nada llevo desde el lunes con esto hehe)
![listo](https://github.com/josejavier1059/mark/assets/72498118/80c0f2c8-7e3e-4bd4-9bf3-401550357df1)
