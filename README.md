# k3s HA chaos lab

Three node Kubernetes cluster on Proxmox that I deploy from code, manage from Git and break on purpose to prove it recovers. Everything in the stack is declared in this repository. The only thing created by hand is one DNS token and that is documented.

I run production alone at my day job and my rule there is simple. Anything I operate must survive me breaking it. This lab applies that rule to Kubernetes. Four drills recreate the four incidents every platform meets sooner or later. A node dies in the middle of the night. A bad deploy ships on a Friday. Traffic spikes. The whole cluster is lost. Each drill is a script with a stopwatch and the numbers land in the table below.

## Results

| Drill | What breaks | Measured on this hardware |
|---|---|---|
| 1. Node death | Hard stop of the VM holding the PostgreSQL primary | fill after first run |
| 2. Broken deploy | Image tag that does not exist pushed to Git | fill after first run |
| 3. Load spike | k6 with 50 virtual users for five minutes | fill after first run |
| 4. Total loss | terraform destroy of all three VMs with the cluster live | fill after first run |

Evidence with logs and screenshots lives in [docs/evidence.md](docs/evidence.md)

## The stack

| Layer | Tool | Why |
|---|---|---|
| Virtual machines | Terraform with the bpg Proxmox provider | The cluster starts from a terraform apply, which is what makes drill 4 possible |
| Cluster | k3s, three servers with embedded etcd | Real quorum. With one master you cannot kill the master and tell the story |
| Deployments | ArgoCD with an app of apps | If it is not in Git it does not exist. Rollback is a revert |
| Stateful workload | PostgreSQL with CloudNativePG | Primary and replica on different nodes with automatic failover |
| Stateless workload | podinfo with 3 replicas and an HPA | Built for demos of health probes and autoscaling |
| Ingress and TLS | Traefik plus cert-manager with DNS challenge | Real certificates on a private cluster, nothing exposed to the internet |
| Load balancing | MetalLB in L2 mode | LoadBalancer services on bare metal like a cloud would give you |
| Observability | kube-prometheus-stack | Alerts for dead nodes and crash loops routed to my usual channel |

## How to run it

```bash
# 1. VMs (fill terraform.tfvars from the example first)
cd terraform && terraform init && terraform apply

# 2. k3s in HA (fill ansible/inventory.yml from the example)
cd ../ansible
git clone https://github.com/k3s-io/k3s-ansible
ansible-playbook k3s-ansible/playbooks/site.yml -i inventory.yml

# 3. ArgoCD and the root app. Git does the rest
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl apply -n argocd -f cluster/bootstrap/root-app.yaml

# 4. The one manual secret (see docs/setup-secrets.md)
kubectl -n cert-manager create secret generic cloudflare-api-token --from-literal=api-token=YOUR_TOKEN
```

Then run the drills in [drills/](drills/) and fill the results table with what your hardware gives you.

## Honest scope

This lab does not recreate multi tenant RBAC at company scale, managed control planes or a service mesh. It recreates operations. Deploying, watching, breaking and recovering a small cluster end to end, with numbers instead of adjectives.

Versions are pinned everywhere on purpose. A lab without pinned versions breaks by itself in three months.
