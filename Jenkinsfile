pipeline {
    agent any

    environment {
        NETLIFY_SITE_ID = 'd50bda29-00dd-4a5c-93c2-e126580efe02'
        NETLIFY_AUTH_TOKEN = credentials('netlify-token')
        REACT_APP_VERSION = "1.0.${BUILD_ID}"
        PLAYWRIGHT_IMAGE = 'my-playwright:latest'
    }

    stages {

        stage('Build custom Docker image') {
            steps {
                sh '''
                    docker build -t ${PLAYWRIGHT_IMAGE} .
                '''
            }
        }

        stage('Build app') {
            agent {
                docker {
                    image 'node:18-alpine'
                    reuseNode true
                }
            }
            steps {
                sh '''
                    set -e
                    ls -la
                    node --version
                    npm --version
                    npm ci
                    npm run build
                    test -f build/index.html
                    ls -la
                    ls -la build
                '''
                stash name: 'app-build', includes: 'build/**'
                stash name: 'app-source', includes: '**', excludes: 'node_modules/**, build/**'
            }
        }

        stage('Tests') {
            parallel {

                stage('Unit tests') {
                    agent {
                        docker {
                            image 'node:18-alpine'
                            reuseNode true
                        }
                    }
                    steps {
                        unstash 'app-source'
                        sh '''
                            set -e
                            npm ci
                            CI=true npm test -- --watchAll=false
                        '''
                    }
                    post {
                        always {
                            junit allowEmptyResults: true, testResults: 'jest-results/junit.xml'
                        }
                    }
                }

                stage('E2E') {
                    agent {
                        docker {
                            image "${PLAYWRIGHT_IMAGE}"
                            reuseNode true
                        }
                    }
                    steps {
                        unstash 'app-source'
                        unstash 'app-build'
                        sh '''
                            set -e
                            npx serve -s build -l 3000 &
                            SERVER_PID=$!

                            for i in $(seq 1 30); do
                                if curl -fs http://127.0.0.1:3000 > /dev/null; then
                                    echo "App is up"
                                    break
                                fi
                                echo "Waiting for app..."
                                sleep 1
                            done

                            export CI_ENVIRONMENT_URL="http://127.0.0.1:3000"
                            npx playwright test --reporter=html

                            kill $SERVER_PID || true
                        '''
                    }
                    post {
                        always {
                            publishHTML([
                                allowMissing: true,
                                alwaysLinkToLastBuild: true,
                                keepAll: true,
                                reportDir: 'playwright-report',
                                reportFiles: 'index.html',
                                reportName: 'Local E2E',
                                reportTitles: '',
                                useWrapperFileDirectly: true
                            ])
                        }
                    }
                }
            }
        }

        stage('Deploy staging') {
            when {
                branch 'main'
            }
            agent {
                docker {
                    image "${PLAYWRIGHT_IMAGE}"
                    reuseNode true
                }
            }
            steps {
                unstash 'app-source'
                unstash 'app-build'

                script {
                    env.CI_ENVIRONMENT_URL = sh(
                        script: '''
                            set -e
                            netlify --version
                            echo "Deploying to staging. Site ID: $NETLIFY_SITE_ID"
                            netlify deploy --site "$NETLIFY_SITE_ID" --dir=build --json > deploy-output.json
                            node-jq -r '.deploy_url' deploy-output.json
                        ''',
                        returnStdout: true
                    ).trim()
                }

                sh '''
                    set -e
                    echo "Staging URL: $CI_ENVIRONMENT_URL"
                    npx playwright test --reporter=html
                '''
            }
            post {
                always {
                    publishHTML([
                        allowMissing: true,
                        alwaysLinkToLastBuild: true,
                        keepAll: true,
                        reportDir: 'playwright-report',
                        reportFiles: 'index.html',
                        reportName: 'Staging E2E',
                        reportTitles: '',
                        useWrapperFileDirectly: true
                    ])
                }
            }
        }

        stage('Approve production deploy') {
            when {
                branch 'main'
            }
            steps {
                input message: 'Deploy to production?', ok: 'Deploy'
            }
        }

        stage('Deploy prod') {
            when {
                branch 'main'
            }
            agent {
                docker {
                    image "${PLAYWRIGHT_IMAGE}"
                    reuseNode true
                }
            }
            steps {
                unstash 'app-source'
                unstash 'app-build'

                sh '''
                    set -e
                    netlify --version
                    echo "Deploying to production. Site ID: $NETLIFY_SITE_ID"
                    netlify deploy --site "$NETLIFY_SITE_ID" --dir=build --prod
                '''

                script {
                    env.CI_ENVIRONMENT_URL = "https://YOUR_NETLIFY_SITE_URL"
                }

                sh '''
                    set -e
                    echo "Production URL: $CI_ENVIRONMENT_URL"
                    npx playwright test --reporter=html
                '''
            }
            post {
                always {
                    publishHTML([
                        allowMissing: true,
                        alwaysLinkToLastBuild: true,
                        keepAll: true,
                        reportDir: 'playwright-report',
                        reportFiles: 'index.html',
                        reportName: 'Prod E2E',
                        reportTitles: '',
                        useWrapperFileDirectly: true
                    ])
                }
            }
        }
    }

    post {
        always {
            echo "Pipeline finished."
        }
        success {
            echo "Pipeline completed successfully."
        }
        failure {
            echo "Pipeline failed."
        }
    }
}