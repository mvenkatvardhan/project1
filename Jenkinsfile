pipeline {
    agent any

    // Configure these in Jenkins: Manage Jenkins > Tools / Global Tool Configuration
    tools {
        nodejs 'NodeJS-20'   // Name must match the NodeJS installation configured in Jenkins
    }

    environment {
        DOCKER_IMAGE       = "venkatvardhan/nodejs-cicd-demo"
        IMAGE_TAG          = "${env.BUILD_NUMBER}"
        SONARQUBE_ENV      = "MySonarQubeServer "   // Name configured in Manage Jenkins > System
        DOCKERHUB_CRED_ID  = "dockerhub-creds"     // Jenkins credential ID (username/password)
    }

    options {
        timestamps()
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Install Dependencies') {
            steps {
                sh 'npm ci'
            }
        }

        stage('Unit Tests') {
            steps {
                sh 'npm test'
            }
            post {
                always {
                    // Requires JUnit-format output; add jest-junit if you want this exact report
                    junit allowEmptyResults: true, testResults: 'reports/junit/*.xml'
                    archiveArtifacts artifacts: 'coverage/**', allowEmptyArchive: true
                }
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv("${SONARQUBE_ENV}") {
                    sh 'npx sonar-scanner'
                }
            }
        }

        stage('Quality Gate') {
            steps {
                // Pauses the pipeline until SonarQube webhook reports pass/fail
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('OWASP Dependency Check') {
            steps {
                sh 'mkdir -p dependency-check-report'
                dependencyCheck additionalArguments: '''
                    --scan .
                    --format HTML
                    --format XML
                    --out dependency-check-report
                    --disableYarnAudit
                ''', odcInstallation: 'OWASP-DepCheck-10'
                dependencyCheckPublisher pattern: 'dependency-check-report/dependency-check-report.xml'
            }
        }

        stage('Docker Build') {
            steps {
                script {
                    dockerImage = docker.build("${DOCKER_IMAGE}:${IMAGE_TAG}")
                }
            }
        }

        stage('Trivy Image Scan') {
            steps {
                sh """
                    trivy image \
                      --severity HIGH,CRITICAL \
                      --exit-code 1 \
                      --format table \
                      --no-progress \
                      ${DOCKER_IMAGE}:${IMAGE_TAG}
                """
            }
        }

        stage('Push to Registry') {
            steps {
                script {
                    docker.withRegistry('https://registry.hub.docker.com', "${DOCKERHUB_CRED_ID}") {
                        dockerImage.push("${IMAGE_TAG}")
                        dockerImage.push("latest")
                    }
                }
            }
        }

        stage('Deploy') {
            steps {
                sh """
                    docker stop nodejs-cicd-demo || true
                    docker rm nodejs-cicd-demo || true
                    docker run -d --name nodejs-cicd-demo -p 3000:3000 ${DOCKER_IMAGE}:${IMAGE_TAG}
                """
            }
        }
    }

    post {
        success {
            echo "Pipeline completed successfully — build ${IMAGE_TAG} deployed."
        }
        failure {
            echo "Pipeline failed — check the stage logs above."
        }
        always {
            cleanWs()
        }
    }
}
