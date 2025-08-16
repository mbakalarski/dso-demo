pipeline {
  agent {
    kubernetes {
      yamlFile 'build-agent.yaml'
      defaultContainer 'maven'
      idleMinutes 1
    }
  }
  stages {
    stage('Build') {
      parallel {
        stage('Compile') {
          steps {
            container('maven') {
              sh 'mvn compile'
            }
          }
        }
      }
    }
    stage('[Test] Static Analysis') {
      parallel {
        stage('[supply chain][compliance] OSS License Checker') {
          steps {
            container('licensefinder') {
              sh 'ls -al'
              sh '''#!/bin/bash --login
                      /bin/bash --login
                      rvm use default
                      gem install license_finder
                      license_finder
                    '''
            }
          }
        }
        stage('[supply chain] Generate SBOM') {
          steps {
            container('maven') {
              sh 'mvn org.cyclonedx:cyclonedx-maven-plugin:makeAggregateBom'
            }
          }
          post {
            success {
              archiveArtifacts allowEmptyArchive: true, artifacts: 'target/bom.xml, target/bom.json', fingerprint: true, onlyIfSuccessful: true
            }
          }
        }
        stage('[supply chain][SCA] OWASP Dependency-Check') {
          steps {
            container('maven') {
              catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
                withCredentials([string(credentialsId: 'nvd-api-key', variable: 'NVD_API_KEY')]) {
                  sh 'mvn org.owasp:dependency-check-maven:check -Dnvd.api.key=$NVD_API_KEY'
                }
              }
            }
          }
          post {
            always {
              archiveArtifacts allowEmptyArchive: true, artifacts: 'target/dependency-check-report.html', fingerprint: true, onlyIfSuccessful: true
              // dependencyCheckPublisher pattern: 'report.xml'
            }
          }
        }

        stage('SAST') {
          steps {
            container('slscan') {
              sh 'scan --type java,depscan --build'
            }
          }
          post {
            success {
              archiveArtifacts allowEmptyArchive: true, artifacts: 'reports/*', fingerprint: true, onlyIfSuccessful: true
            }
          }
        }

        stage('Unit Tests') {
          steps {
            container('maven') {
              sh 'mvn test'
            }
          }
        }
      }
    }
    stage('Package') {
      parallel {
        stage('Create Jarfile') {
          steps {
            container('maven') {
              sh 'mvn package -DskipTests'
            }
          }
        }
        stage('OCI Image BnP') {
          steps {
            container('kaniko') {
              sh '/kaniko/executor -f `pwd`/Dockerfile -c `pwd` --skip-tls-verify --destination=docker.io/mbakalarski/private:dso-demo-multistage'
            }
          }
        }
      }
    }
    stage('Get Registry Creds') {
      steps {
        container('bash') {
          sh 'apk add jq --no-cache'
          script {
            def regcredUsername = sh(script: 'cat /tmp/.docker/config.json | jq -r \'.auths."https://index.docker.io/v1/".username\'', returnStdout: true).trim()
            def regcredPassword = sh(script: 'cat /tmp/.docker/config.json | jq -r \'.auths."https://index.docker.io/v1/".password\'', returnStdout: true).trim()
            env.REGCRED_USERNAME = regcredUsername
            env.REGCRED_PASSWORD = regcredPassword
          }
        }
      }
    }
    stage('OCI Image Analysis') {
      parallel {
        stage('Image Linting') {
          steps {
            container('docker-tools') {
              script {
                env.DOCKLE_USERNAME = "${env.REGCRED_USERNAME}"
                env.DOCKLE_PASSWORD = "${env.REGCRED_PASSWORD}"
              }
              sh 'dockle docker.io/mbakalarski/private:dso-demo-multistage'
            }
          }
        }
        stage('Image Scan') {
          steps {
            container('docker-tools') {
              script {
                env.TRIVY_USERNAME = "${env.REGCRED_USERNAME}"
                env.TRIVY_PASSWORD = "${env.REGCRED_PASSWORD}"
              }
              sh 'trivy image --timeout 10m --severity CRITICAL --exit-code 1 docker.io/mbakalarski/private:dso-demo-multistage'
            }
          }
        }
      }
    }
    stage('Deploy to Dev') {
      environment {
        ARGO_SERVER = "192.168.122.43:30102"
      }
      steps {
        container('bash') {
          sh '''
            apk add curl --no-cache &&
            curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64 &&
            install -m 555 argocd-linux-amd64 /usr/local/bin/argocd &&
            rm argocd-linux-amd64
          '''
          withCredentials([string(credentialsId: 'argocd-jenkins-deployer-token', variable: 'AUTH_TOKEN')]) {
            sh 'argocd app sync dso-demo --insecure --server $ARGO_SERVER --auth-token $AUTH_TOKEN'
            sh 'argocd app wait dso-demo --health --timeout 300 --insecure --server $ARGO_SERVER --auth-token $AUTH_TOKEN'
          }
        }
      }
    }
  }
}
