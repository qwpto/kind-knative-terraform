# rabbit MQ setup https://knative.dev/docs/eventing/brokers/broker-types/rabbitmq-broker/

variable "rabbitmq_broker_config_name" {
  type = string
  default = "default-config"
}

variable "rabbitmq_broker_name" {
  type = string
  default = "default"
}

variable "rabbitmq_namespace" {
  type = string
  default = "rabbitmq-ns"
}

variable "rabbitmq_clustername" {
  type = string
  default = "rabbitmq"
}

locals {
  RabbitMQBrokerConfig = <<-EOF
    apiVersion: eventing.knative.dev/v1alpha1
    kind: RabbitmqBrokerConfig
    metadata:
      name: ${var.rabbitmq_broker_config_name}
      namespace: ${var.rabbitmq_namespace}
    spec:
      rabbitmqClusterReference:
        # Configure name if a RabbitMQ Cluster Operator is being used.
        name: ${var.rabbitmq_clustername}
        namespace: ${var.rabbitmq_namespace}
        # Configure connectionSecret if an external RabbitMQ cluster is being used.
        # connectionSecret:
        #   name: rabbitmq-secret-credentials
      queueType: quorum
  EOF

  RabbitMQBrokerObject = <<-EOF
    apiVersion: eventing.knative.dev/v1
    kind: Broker
    metadata:
      name: ${var.rabbitmq_broker_name}
      namespace: ${var.rabbitmq_namespace}
      annotations:
        eventing.knative.dev/broker.class: RabbitMQBroker
    spec:
      config:
        apiVersion: eventing.knative.dev/v1alpha1
        kind: RabbitmqBrokerConfig
        name: ${var.rabbitmq_broker_config_name}
      delivery:
        deadLetterSink:
            ref:
                apiVersion: serving.knative.dev/v1
                kind: Service
                name: event-display
                namespace: ${var.rabbitmq_namespace}
  EOF

#   namespace = <<-EOF
#     apiVersion: v1
#     kind: Namespace
#     metadata:
#         name: ${var.rabbitmq_namespace}
#   EOF

  RabbitMqLocalCluster = <<-EOF
    # RabbitMQ cluster used by the Broker
    apiVersion: rabbitmq.com/v1beta1
    kind: RabbitmqCluster
    metadata:
      name: ${var.rabbitmq_clustername}
      namespace: ${var.rabbitmq_namespace}
    spec:
      replicas: 1
      override:
        statefulSet:
          spec:
            template:
              spec:
                containers:
                - name: rabbitmq
                  env:
                  - name: ERL_MAX_PORTS
                    value: "4096"
  EOF

  eventDisplay  = <<-EOF
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: event-display
  namespace: ${var.rabbitmq_namespace}
spec:
  template:
    spec:
      containers:
      - image: gcr.io/knative-releases/knative.dev/eventing/cmd/event_display
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

  #for local rabbitmq
  provisioner "local-exec" {
    command = "kubectl apply -f https://github.com/rabbitmq/cluster-operator/releases/latest/download/cluster-operator.yml"
  }
  provisioner "local-exec" {
    command = "kubectl wait pod --timeout=-1s --for=condition=Ready -l !job-name -n rabbitmq-system"
  }

  provisioner "local-exec" {
    command = "kubectl create ns ${var.rabbitmq_namespace}"
  }

#   provisioner "local-exec" {
#     command = "kubectl apply -f rabbitmqsecret.yaml"
#   }

  # provisioner "local-exec" {
  #   command = "kubectl apply -f - << EOF ${local.RabbitMQBrokerObject} EOF"
  # }

  #default ordering https://knative.dev/v1.7-docs/eventing/brokers/broker-types/rabbitmq-broker/#configure-message-ordering
  #https://docs.vmware.com/en/Cloud-Native-Runtimes-for-VMware-Tanzu/2.0/tanzu-cloud-native-runtimes/GUID-verifying-eventing.html

  depends_on = [ null_resource.install_knative_eventing ]
}

resource "time_sleep" "wait_for_install" {
  depends_on = [null_resource.install_rabbitmq]

  create_duration = "180s"
}

resource "kubectl_manifest" "RabbitMQlocalinstance" {
  yaml_body = local.RabbitMqLocalCluster
  depends_on = [
    time_sleep.wait_for_install
  ]
}

resource "null_resource" "wait_RabbitMQlocalinstance" {
  provisioner "local-exec" {
    command = "kubectl wait pod --timeout=-1s --for=condition=Ready -l !job-name -n ${var.rabbitmq_namespace}"
  }
  depends_on = [ kubectl_manifest.RabbitMQlocalinstance ]
}  

resource "kubectl_manifest" "RabbitMQBrokerConfig" {
  yaml_body = local.RabbitMQBrokerConfig
  depends_on = [
    null_resource.wait_RabbitMQlocalinstance
  ]
}

resource "kubectl_manifest" "RabbitMQBrokerObject" {
  yaml_body = local.RabbitMQBrokerObject
  depends_on = [
    kubectl_manifest.RabbitMQBrokerConfig
  ]
}

resource "kubectl_manifest" "RabbitMQEventDisplay" {
  yaml_body = local.eventDisplay
  depends_on = [
    kubectl_manifest.RabbitMQBrokerObject
  ]
}

#do this example: https://github.com/knative-sandbox/eventing-rabbitmq/tree/main/samples/external-cluster

# 
