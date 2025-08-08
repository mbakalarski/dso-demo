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
        stage('[supply chain] OWASP Dependency-Check') {
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
              sh '/kaniko/executor -f `pwd`/Dockerfile -c `pwd` --skip-tls-verify --destination=docker.io/mbakalarski/private:dso-demo-0.1'
            }
          }
        }
      }
    }
    stage('OCI Image Analysis') {
      parallel {
        stage('Image Linting') {
          steps {
            container('docker-tools') {
              sh '''
                apk add jq && \
                apk add jq && \
                dockle \
                --username $(cat /tmp/.docker/config.json | jq -r '.auths."https://index.docker.io/v1/".username') \
                --password $(cat /tmp/.docker/config.json | jq -r '.auths."https://index.docker.io/v1/".password') \
                docker.io/mbakalarski/private:dso-demo-0.1
              '''
            }
          }
        }
        stage('Image Scan') {
          steps {
            container('docker-tools') {
              sh 'trivy image --timeout 10m --exit-code 1 mbakalarski/private:dso-demo-0.1'
            }
          }
        }
      }
    }

    stage('Deploy to Dev') {
      steps {
        // TODO
        sh "echo done"
      }
    }
  }
}
