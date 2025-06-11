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
              terraform fmt
              
              
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
      sh "sed -i 's|<bastionhost.public_ip>|${bastionIp}|' ansible/ansible.cfg"
    }
  }
}

       stage('Install KAFKA with Ansible') {
      steps {
        dir('ansible') {
          withCredentials([
            [$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws_cred'],
            sshUserPrivateKey(credentialsId: 'kafka_key', keyFileVariable: 'SSH_KEY')
          ]) {
             script {
          def bastionIp = sh(script: "terraform -chdir=../terraform output -raw bastionhost_public_ip", returnStdout: true).trim()

          sh '''
            echo "Copying slave.pem to Bastion (${bastionIp})"
            scp -o StrictHostKeyChecking=no -i $SSH_KEY $SSH_KEY ${SSH_USER}@${bastionIp}:/home/${SSH_USER}/slave.pem
            ssh -o StrictHostKeyChecking=no -i $SSH_KEY ${SSH_USER}@${bastionIp} "chmod 400 /home/${SSH_USER}/slave.pem"
          '''
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
