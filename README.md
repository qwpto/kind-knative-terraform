# kind-knative-terraform

This is demo enviroment of knative, and it is refer to https://github.com/csantanapr/knative-kind, but use nats-streaming as component of eventing instead of in-memory

## Prerequisites
- [terraform](https://www.terraform.io/downloads.html)
- [docker](https://www.docker.com/products/docker-desktop) or [podman](https://podman.io/getting-started/installation)
- [kind](https://kind.sigs.k8s.io/docs/user/quick-start#installation)
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- [helm](https://helm.sh/docs/intro/install/)

## Usage
initialize terraform module
```bash
$ terraform init
```
launch knative enviroment at kind cluster
```bash
$ terraform apply -auto-approve
```
List all pods from kind cluster
```bash
>kubectl get pods --all-namespaces
NAMESPACE            NAME                                            READY   STATUS    RESTARTS   AGE
knative-eventing     eventing-controller-647f575b78-s97r2            1/1     Running   0          12m
knative-eventing     eventing-webhook-6d9dd8d8cd-69g48               1/1     Running   0          12m
knative-eventing     nats-webhook-7cbff6b6dd-9bv87                   1/1     Running   0          11m
knative-eventing     natss-ch-controller-6f79965956-c6vr9            1/1     Running   0          11m
knative-eventing     natss-ch-dispatcher-848cf558f5-kwjwc            1/1     Running   0          11m
knative-serving      activator-648f778cfd-tbnn9                      1/1     Running   0          13m
knative-serving      autoscaler-64f7fbc57f-wghvj                     1/1     Running   0          13m
knative-serving      controller-5855dcb94-ds9fb                      1/1     Running   0          13m
knative-serving      domain-mapping-65f96fff86-lhgtz                 1/1     Running   0          13m
knative-serving      domainmapping-webhook-d49d4cdd4-gff77           1/1     Running   0          13m
knative-serving      net-kourier-controller-66546b8545-x9msd         1/1     Running   0          12m
knative-serving      webhook-87fbc58c5-769jr                         1/1     Running   0          13m
kourier-system       3scale-kourier-gateway-6966cb4956-vtktr         1/1     Running   0          12m
kube-system          coredns-78fcd69978-6dwx9                        1/1     Running   0          13m
kube-system          coredns-78fcd69978-hrgrv                        1/1     Running   0          13m
kube-system          etcd-knative-control-plane                      1/1     Running   0          14m
kube-system          kindnet-7c5n9                                   1/1     Running   0          13m
kube-system          kube-apiserver-knative-control-plane            1/1     Running   0          14m
kube-system          kube-controller-manager-knative-control-plane   1/1     Running   0          14m
kube-system          kube-proxy-klgs5                                1/1     Running   0          13m
kube-system          kube-scheduler-knative-control-plane            1/1     Running   0          14m
local-path-storage   local-path-provisioner-58c8ccd54c-qzjcd         1/1     Running   0          13m
natss                nats-streaming-0                                2/2     Running   0          11m
```
destroy kind cluster
```bash
$ terraform destroy -auto-approve
```

DEBUGGING:
kubectl get pods --all-namespaces
kubectl describe pods --all-namespaces
kubectl get all -n metallb
kubectl logs pod/metallb-controller-c55c89d-x9kj7
kubectl get pod -n kube-system -o wide
kubectl get svc kubernetes
kubectl logs <cilium-pod-that-failed-to-start>  -n kube-system --previous --timestamps
cilium status
kubectl --namespace kourier-system get service kourier
kubectl get ksvc
kubectl describe configmap/config-network --namespace knative-serving
kubectl apply --filename service.yaml
curl -v http://helloworld-go.default.127.0.0.1.sslip.io
kubectl get -n knative-eventing cm config-br-defaults -o yaml 
kubectl -n default get brokers