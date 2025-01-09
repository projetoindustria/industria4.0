pipeline {
    agent any

    tools {
        jdk "jdk23"
        maven "maven3"
    }
    
    environment{
        SCANNER_HOME = tool 'sonar-scanner'
        APP_NAME = "industria-server"
        RELEASE = "1.0"
        IMAGE_TAG = "${RELEASE}-${BUILD_NUMBER}"
    }

    stages {
        stage('Clean workspace') {
            steps {
                cleanWs()
            }
        }

        stage('Load env file') {
            steps {
                withCredentials([file(credentialsId: 'env-file', variable: 'mySecretEnvFile')]){
                    sh 'cp -rf $mySecretEnvFile $WORKSPACE'
                }
            }
        }

        stage('Checkout from git') {
            steps {
                withCredentials([string(credentialsId: 'github-url', variable: 'GITHUB_URL')]) {
                    git branch: 'main', changelog: false, credentialsId: 'github-creds', poll: false, url: "${GITHUB_URL}"
                }
            }
        }
        
        stage('Trivy scan file system') {
            steps {
                sh 'trivy fs --format table -o trivy-fs-report.html .'
            }
        }

        stage('Sonarqube analysis') {
            steps {
                withSonarQubeEnv('sonarqube') {
                    withCredentials([string(credentialsId: 'sonarqube-token', variable: 'SONARQUBE_TOKEN')]) {
                        sh '$SCANNER_HOME/bin/sonar-scanner -Dsonar.projectName=$APP_NAME -Dsonar.projectKey=$APP_NAME -Dsonar.java.binaries=. -Dsonar.login=$SONARQUBE_TOKEN'
                    }
                }
            }
        }
        
        stage('Quality gate') {
            steps {
                script {
                    waitForQualityGate abortPipeline: true
                }
            }
        }


        stage('Build') {
            steps {
                sh 'mvn clean package -DskipTests'
            }
        }
        
        stage('Build Docker Image') {
            steps {
                script {
                    withCredentials([string(credentialsId: 'dockerhub-user', variable: 'DOCKERHUB_USR')]) {
                        docker_image = docker.build("${DOCKERHUB_USR}/${APP_NAME}")
                    }
                }
            }
        }
        
        stage('Trivy scan image') {
            steps {
                withCredentials([string(credentialsId: 'dockerhub-user', variable: 'DOCKERHUB_USR')]) {
                    sh 'trivy image --severity HIGH,CRITICAL --format table -o trivy-image-report.html $DOCKERHUB_USR/$APP_NAME'
                }
            }
        }

        stage('Push Docker Image') {
            steps {
                script {
                    withDockerRegistry(credentialsId: 'dockerhub-creds', toolName: 'docker') {
                        docker_image.push("${IMAGE_TAG}")
                        docker_image.push('latest')
                    }
                }
            }
        }

        
        stage('Cleaning up') { 
            steps { 
                script {
                    withCredentials([string(credentialsId: 'dockerhub-user', variable: 'DOCKERHUB_USR')]) {
                        sh 'docker rmi $DOCKERHUB_USR/$APP_NAME:$IMAGE_TAG' 
                        sh 'docker rmi $DOCKERHUB_USR/$APP_NAME:latest'
                        sh '''docker rmi $(docker images --filter "dangling=true" -q --no-trunc)'''
                    }   
                }
            }
        }        
    }

    post {
        always {
            emailext attachLog: true,
                     subject: "'${currentBuild.result}'",
                     body: "Project: ${env.JOB_NAME}<br/>" +
                           "Build Number: ${env.BUILD_NUMBER}<br/>" +
                           "URL: ${env.BUILD_URL}<br/>",
                     to: 'projetoindustriaifsul@gmail.com',
                     attachmentsPattern: 'trivy-fs-report.html,trivy-image-report.html'
        }
    }
}
