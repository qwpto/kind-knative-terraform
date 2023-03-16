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

resource "helm_release" "nats-streaming" {
  name       = "nats-stan"
  repository = "https://nats-io.github.io/k8s/helm/charts/"
  chart      = "stan"
  version    = "0.7.4"
  namespace  = "natss"

  values = [
    <<EOF
    stan:
      clusterID: knative-nats-streaming
      logging:
        debug: true
        trace: true
    nameOverride: nats-streaming
    store:
      volume:
        storageClass: standard
    EOF
  ]
  
  create_namespace = true

  depends_on = [ null_resource.install_knative_eventing ]
}

resource "null_resource" "install_the_nats_streaming_channel" {
  provisioner "local-exec" {
    command = "kubectl apply --filename https://github.com/knative-sandbox/eventing-natss/releases/download/knative-${var.NATSS_EVENTING_VERSION}/eventing-natss.yaml"
  }
  provisioner "local-exec" {
    command = "kubectl wait deployment --all --timeout=-1s --for=condition=Available -n knative-eventing"
  }
  
  depends_on = [ helm_release.nats-streaming ]
}