resource "null_resource" "install_knative_eventing" {
  provisioner "local-exec" {
    command = "kubectl apply -f https://github.com/knative/eventing/releases/download/knative-${var.KNATIVE_EVENTING_VERSION}/eventing-crds.yaml"
  }
  provisioner "local-exec" {
    command = "kubectl wait --for=condition=Established --all crd"
  }
  provisioner "local-exec" {
    command = "kubectl apply -f https://github.com/knative/eventing/releases/download/knative-${var.KNATIVE_EVENTING_VERSION}/eventing-core.yaml"
  }
  provisioner "local-exec" {
    command = "kubectl wait pod --timeout=-1s --for=condition=Ready -l !job-name -n knative-eventing"
  }
  depends_on = [ null_resource.configure_knative_to_use_kourier ]
}

# resource "helm_release" "nats-streaming" {
#   name       = "nats-stan"
#   repository = "https://nats-io.github.io/k8s/helm/charts/"
#   chart      = "stan"
#   version    = "0.7.4"
#   namespace  = "natss"

#   values = [
#     <<EOF
#     stan:
#       clusterID: knative-nats-streaming
#       logging:
#         debug: true
#         trace: true
#     nameOverride: nats-streaming
#     store:
#       volume:
#         storageClass: standard
#     EOF
#   ]
  
#   create_namespace = true

#   depends_on = [ null_resource.install_knative_eventing ]
# }

# resource "null_resource" "install_the_nats_streaming_channel" {
#   provisioner "local-exec" {
#     command = "kubectl apply --filename https://github.com/knative-sandbox/eventing-natss/releases/download/knative-${var.NATSS_EVENTING_VERSION}/eventing-natss.yaml"
#   }
#   provisioner "local-exec" {
#     command = "kubectl wait deployment --all --timeout=-1s --for=condition=Available -n knative-eventing"
#   }
  
#   depends_on = [ helm_release.nats-streaming ]
# }

################################
# rabbit MQ setup https://knative.dev/docs/eventing/brokers/broker-types/rabbitmq-broker/

variable "rabbitmq_broker_config_name" {
  type = string
  default = "rabbitmq-broker-config"
}

variable "rabbitmq_broker_name" {
  type = string
  default = "rabbitmq-broker"
}

locals {
  RabbitMQBrokerConfig = <<-EOF
    apiVersion: eventing.knative.dev/v1alpha1
    kind: RabbitmqBrokerConfig
    metadata:
      name: ${var.rabbitmq_broker_config_name}
    spec:
      rabbitmqClusterReference:
        # Configure name if a RabbitMQ Cluster Operator is being used.
        #name: <cluster-name>
        # Configure connectionSecret if an external RabbitMQ cluster is being used.
        connectionSecret:
          name: rabbitmq-secret-credentials
      queueType: quorum
  EOF

  RabbitMQBrokerObject = <<-EOF
    apiVersion: eventing.knative.dev/v1
    kind: Broker
    metadata:
      annotations:
        eventing.knative.dev/broker.class: RabbitMQBroker
      name: ${var.rabbitmq_broker_name}
    spec:
      config:
        apiVersion: eventing.knative.dev/v1alpha1
        kind: RabbitmqBrokerConfig
        name: ${var.rabbitmq_broker_config_name}
  EOF
}

# variable "RabbitMQBrokerObject" {
#   type = string
#   default = <<-EOF
#     apiVersion: eventing.knative.dev/v1
#     kind: Broker
#     metadata:
#       annotations:
#         eventing.knative.dev/broker.class: RabbitMQBroker
#       name: ${var.rabbitmq_broker_name}
#     spec:
#       config:
#         apiVersion: rabbitmq.com/v1beta1
#         kind: RabbitmqBrokerConfig
#         name: ${var.rabbitmq_broker_config_name}
#   EOF
# }

resource "null_resource" "install_rabbitmq" {
  provisioner "local-exec" {
    command = "kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.5.4/cert-manager.yaml"
  }
  provisioner "local-exec" {
    command = "kubectl wait pod --timeout=-1s --for=condition=Ready -l !job-name -n cert-manager"
  }

  provisioner "local-exec" {
    command = "kubectl apply -f https://github.com/rabbitmq/messaging-topology-operator/releases/latest/download/messaging-topology-operator-with-certmanager.yaml"
  }
  provisioner "local-exec" {
    command = "kubectl wait pod --timeout=-1s --for=condition=Ready -l !job-name -n rabbitmq-system"
  }

  provisioner "local-exec" {
    command = "kubectl apply -f https://github.com/knative-sandbox/eventing-rabbitmq/releases/download/knative-v1.7.2/rabbitmq-broker.yaml"
  }
  provisioner "local-exec" {
    command = "kubectl wait deployment --all --timeout=-1s --for=condition=Available -n knative-eventing"
  }

  provisioner "local-exec" {
    command = "kubectl apply -f rabbitmqsecret.yaml"
  }

  # provisioner "local-exec" {
  #   command = "kubectl apply -f - << EOF ${local.RabbitMQBrokerObject} EOF"
  # }

  #default ordering https://knative.dev/v1.7-docs/eventing/brokers/broker-types/rabbitmq-broker/#configure-message-ordering
  #https://docs.vmware.com/en/Cloud-Native-Runtimes-for-VMware-Tanzu/2.0/tanzu-cloud-native-runtimes/GUID-verifying-eventing.html

  depends_on = [ null_resource.install_knative_eventing ]
}

resource "kubectl_manifest" "RabbitMQBrokerConfig" {
  yaml_body = local.RabbitMQBrokerConfig
  depends_on = [
    null_resource.install_rabbitmq
  ]
}

resource "kubectl_manifest" "RabbitMQBrokerObject" {
  yaml_body = local.RabbitMQBrokerObject
  depends_on = [
    kubectl_manifest.RabbitMQBrokerConfig
  ]
}

#do this example: https://github.com/knative-sandbox/eventing-rabbitmq/tree/main/samples/external-cluster
