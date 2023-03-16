resource "kind_cluster" "knative" {
  name = "knative"
  node_image = "kindest/node:${var.KIND_VERSION}"
  kind_config = <<KIONF
    kind: Cluster
    apiVersion: kind.x-k8s.io/v1alpha4
    nodes:
    - role: control-plane
      extraPortMappings:
      - containerPort: 31080
        hostPort: 80
  KIONF
  wait_for_ready = true

  provisioner "local-exec" {
    when    = destroy
    command = "del ${self.kubeconfig_path}"
  }
}