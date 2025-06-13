pipeline {
  agent any

  environment {
    AWS_REGION = 'ap-south-1'
    SSH_USER = 'ubuntu'
  }

  parameters {
    booleanParam(name: 'DESTROY_INFRA', defaultValue: false, description: 'Destroy infrastructure after run?')
  }

  stages {
    stage('Terraform Init') {
      when {
        expression { return !params.DESTROY_INFRA }
      }
      steps {
        dir('terraform') {
          withCredentials([[
            $class: 'AmazonWebServicesCredentialsBinding',
            credentialsId: 'aws_cred'
          ]]) {
            sh '''
              export AWS_REGION=${AWS_REGION}
              terraform init
            '''
          }
        }
      }
    }

    stage('Terraform FMT & Validate') {
      when {
        expression { return !params.DESTROY_INFRA }
      }
      steps {
        dir('terraform') {
          sh '''
            terraform fmt
            terraform validate
          '''
        }
      }
    }

    stage('Terraform Plan') {
      when {
        expression { return !params.DESTROY_INFRA }
      }
      steps {
        dir('terraform') {
          withCredentials([[
            $class: 'AmazonWebServicesCredentialsBinding',
            credentialsId: 'aws_cred'
          ]]) {
            sh 'terraform plan'
          }
        }
      }
    }

    stage('Approve Terraform Apply') {
      when {
        expression { return !params.DESTROY_INFRA }
      }
      steps {
        input message: 'Do you want to proceed with Terraform Apply?'
      }
    }

    stage('Terraform Apply') {
      when {
        expression { return !params.DESTROY_INFRA }
      }
      steps {
        dir('terraform') {
          withCredentials([[
            $class: 'AmazonWebServicesCredentialsBinding',
            credentialsId: 'aws_cred'
          ]]) {
            sh '''
              export AWS_REGION=${AWS_REGION}
              terraform apply -auto-approve
            '''
          }
        }
      }
    }

    stage('Inject Bastion IP into Ansible Config') {
      when {
        expression { return !params.DESTROY_INFRA }
      }
      steps {
        script {
          def bastionIp = sh(script: "terraform -chdir=terraform output -raw bastionhost_public_ip", returnStdout: true).trim()
          sh "sed -i 's|<bastionhost.public_ip>|${bastionIp}|' ansible/ansible.cfg"
        }
      }
    }

    stage('Install KAFKA with Ansible') {
      when {
        expression { return !params.DESTROY_INFRA }
      }
      steps {
        dir('ansible') {
          withCredentials([
            [$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws_cred'],
            sshUserPrivateKey(credentialsId: 'kafka_key', keyFileVariable: 'SSH_KEY')
          ]) {
            script {
              def bastionIp = sh(script: "terraform -chdir=../terraform output -raw bastionhost_public_ip", returnStdout: true).trim()

              sh """
                echo "Copying slave.pem to Bastion (${bastionIp})"
                scp -o StrictHostKeyChecking=no -i "$SSH_KEY" "$SSH_KEY" ${SSH_USER}@${bastionIp}:/tmp/slave.pem

                ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" ${SSH_USER}@${bastionIp} '
                  sudo mv /tmp/slave.pem /home/${SSH_USER}/slave.pem &&
                  sudo chown ${SSH_USER}:${SSH_USER} /home/${SSH_USER}/slave.pem &&
                  sudo chmod 400 /home/${SSH_USER}/slave.pem
                '
              """

              sh '''
                export AWS_REGION=${AWS_REGION}
                pip3 install --upgrade pip
                pip3 install -r requirements.txt
                sed -i "s|~/.ssh/slave.pem|/tmp/slave.pem|g" ansible.cfg
                sed -i "s|~/.ssh/slave.pem|/tmp/slave.pem|g" aws_ec2.yaml
                ansible-galaxy collection install amazon.aws
                ansible-inventory -i aws_ec2.yaml --graph
                ansible-playbook -i aws_ec2.yaml kafka.yml
              '''
            }
          }
        }
      }
    }

    stage('Approve Terraform Destroy') {
      when {
        expression { return params.DESTROY_INFRA }
      }
      steps {
        input message: 'Are you sure you want to destroy the infrastructure?'
      }
    }

    stage('Terraform Destroy') {
      when {
        expression { return params.DESTROY_INFRA }
      }
      steps {
        dir('terraform') {
          withCredentials([[
            $class: 'AmazonWebServicesCredentialsBinding',
            credentialsId: 'aws_cred'
          ]]) {
            sh '''
              export AWS_REGION=${AWS_REGION}
              terraform destroy -auto-approve
            '''
          }
        }
      }
    }
  }

  post {
    success {
      slackSend (
        channel: '#jenkins',
        color: 'good',
        message: "Kafka Deployment Pipeline completed successfully. <${env.BUILD_URL}|View Job>"
      )
      mail to: 'ishaanaggarwal32@gmail.com',
           subject: 'SUCCESS: Kafka Deployment Pipeline',
           body: "Build #${env.BUILD_NUMBER} succeeded.\n\nCheck Jenkins for details:\n${env.BUILD_URL}"
    }
    failure {
      slackSend (
        channel: '#jenkins',
        color: 'danger',
        message: "Kafka Deployment Pipeline failed. <${env.BUILD_URL}|View Job>"
      )
      mail to: 'ishaanaggarwal32@gmail.com',
           subject: 'FAILURE: Kafka Deployment Pipeline',
           body: "Build #${env.BUILD_NUMBER} failed.\n\nCheck Jenkins for details:\n${env.BUILD_URL}"
    }
  
  }
}
