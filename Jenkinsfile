pipeline {
  agent any

  environment {
    AWS_REGION = 'ap-south-1'
  }

  parameters {
    booleanParam(name: 'DESTROY_INFRA', defaultValue: false, description: 'Destroy infrastructure after run?')
  }

  stages {
    stage('Checkout') {
      steps {
        git url: 'https://github.com/Ishaan-Dev5/Kafka.git', branch: 'main'
      }
    }

    stage('Terraform Init & Apply') {
      steps {
        dir('terraform') {
          withCredentials([[
            $class: 'AmazonWebServicesCredentialsBinding',
            credentialsId: 'aws_cred'
          ]]) {
            sh '''
              export AWS_REGION=${AWS_REGION}
              terraform init
              terraform apply -auto-approve
            '''
          }
        }
      }
    }

    stage('Inject Bastion IP into Ansible Config') {
  steps {
    script {
      def bastionIp = sh(script: "terraform -chdir=terraform output -raw bastionhost_public_ip", returnStdout: true).trim()
      sh "sed -i 's|<bastionhost.public_ip>|${bastionIp}|' ansible/kafka_install/ansible.cfg"
    }
  }
}

       stage('Install KAFKA with Ansible') {
      steps {
        dir('ansible/kafka_install') {
          withCredentials([
            [$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws_cred'],
            sshUserPrivateKey(credentialsId: 'kafka_key', keyFileVariable: 'SSH_KEY')
          ]) {
            sh '''
              export AWS_REGION=${AWS_REGION}
              pip3 install --upgrade pip
              pip3 install -r requirements.txt

              sed -i "s|~/.ssh/slave.pem|$SSH_KEY|g" ansible.cfg
              sed -i "s|~/.ssh/slave.pem|$SSH_KEY|g" aws_ec2.yaml

              ansible-inventory -i aws_ec2.yaml --graph
              ansible-playbook -i aws_ec2.yaml kafka.yml
              ansible-galaxy collection install amazon.aws
            '''
          }
        }
      }
    }


    stage('Terraform Destroy (Optional)') {
      when {
        expression { return params.DESTROY_INFRA == true }
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
}
