pipeline {
    agent any

    stages {
        stage('Build') {
            agent {
                docker {
                    image 'node:18-alpine'
                    reuseNode true
                }
            }
            steps {
                echo 'Build stage'
                sh '''
                    set -e
                    ls -la
                    node --version
                    npm --version
                    npm ci
                    npm run build
                '''
            }
        }

        stage('Test') {
            agent {
                docker {
                    image 'node:18-alpine'
                    reuseNode true
                }
            }
            steps {
                echo 'Test stage'
                sh '''
                    set -e
                    test -e build/index.html
                    npm test
                '''
            }
        }

        stage('E2E') {
            agent {
                docker {
                    image 'mcr.microsoft.com/playwright:v1.39.0-noble'
                    reuseNode true
                }
            }
            steps {
                sh '''
                    set -e
                    echo "E2E stage"

                    node --version
                    npm --version

                    npm ci

                    node_modules/.bin/serve -s build -l 3000 &
                    SERVER_PID=$!

                    sleep 5

                    npx playwright test --workers=1

                    kill $SERVER_PID
                '''
            }
        }
    }

    post {
        always {
            junit allowEmptyResults: true, testResults: 'test-results/junit.xml'
        }
    }
}