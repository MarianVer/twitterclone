pipeline {
    agent any
    
    environment {
        DOCKER_HOST = "unix:///var/run/docker.sock"
        PYTHONPATH = "${WORKSPACE}"
    }
    
    stages {
        stage('Checkout Code') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/your-username/your-repo.git',
                    credentialsId: 'github-credentials'
                script {
                    currentBuild.description = "Commit: ${env.GIT_COMMIT}"
                }
            }
        }
        
        stage('Install Dependencies') {
            steps {
                sh 'pip install -r requirements.txt'
            }
        }
        
        stage('Run Python Tests') {
            steps {
                script {
                    try {
                        // Базові тести
                        sh 'python -m pytest tests/ -v --junitxml=test-results/pytest.xml || true'
                        
                        // Додаткові перевірки (якщо є manage.py - можливо Django)
                        if (fileExists('manage.py')) {
                            sh 'python manage.py test --no-input --testrunner=xmlrunner.extra.djangotestrunner.XMLTestRunner --output-file=test-results/django.xml || true'
                        }
                    } catch (Exception e) {
                        echo "Tests failed but continuing: ${e.message}"
                    }
                }
            }
            post {
                always {
                    junit 'test-results/*.xml'
                    archiveArtifacts artifacts: 'test-results/*.xml', allowEmptyArchive: true
                }
            }
        }
        
        stage('Build Docker Images') {
            steps {
                script {
                    // Білд основного додатку
                    if (fileExists('Dockerfile')) {
                        docker.build("your-app:${env.BUILD_ID}")
                    }
                    
                    // Білд Jenkins образів через Terraform
                    dir('terraform') {
                        sh 'terraform init'
                        sh 'terraform apply -auto-approve -var="jenkins_secret=${JENKINS_SECRET}"'
                    }
                }
            }
        }
        
        stage('Deploy Application') {
            steps {
                script {
                    if (fileExists('docker-compose.yml')) {
                        sh 'docker-compose up -d --build'
                    }
                }
            }
        }
        
        stage('Health Check') {
            steps {
                script {
                    // Перевірка чи працює додаток
                    sleep time: 30, unit: 'SECONDS'
                    sh 'curl -f http://localhost:8080 || echo "Application might be starting..."'
                }
            }
        }
    }
    
    post {
        always {
            script {
                // Отримуємо URL Jenkins з Terraform output
                def tfOutput = sh(script: 'cd terraform && terraform output -raw jenkins_url', returnStdout: true).trim()
                echo "Jenkins is available at: ${tfOutput}"
                
                // Зберігаємо артефакти
                archiveArtifacts artifacts: '**/*.py,**/requirements.txt', allowEmptyArchive: true
            }
            
            // Cleanup
            sh 'docker system prune -f || true'
        }
        
        success {
            slackSend(
                channel: '#jenkins',
                message: "✅ Build SUCCESS: ${env.JOB_NAME} - ${env.BUILD_URL}"
            )
        }
        
        failure {
            slackSend(
                channel: '#jenkins',
                message: "❌ Build FAILED: ${env.JOB_NAME} - ${env.BUILD_URL}"
            )
        }
        
        unstable {
            slackSend(
                channel: '#jenkins',
                message: "⚠️ Build UNSTABLE: ${env.JOB_NAME} - ${env.BUILD_URL}"
            )
        }
    }
}
