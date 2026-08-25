# k3s HA chaos lab

Three node Kubernetes cluster on Proxmox that I deploy from code, manage from Git and break on purpose to prove it recovers. Everything in the stack is declared in this repository. The only thing created by hand is one DNS token and that is documented.

I run production alone at my day job and my rule there is simple. Anything I operate must survive me breaking it. This lab applies that rule to Kubernetes. Four drills recreate the four incidents every platform meets sooner or later. A node dies in the middle of the night. A bad deploy ships on a Friday. Traffic spikes. The whole cluster is lost. Each drill is a script with a stopwatch and the numbers land in the table below.

## Results

| Drill | What breaks | Measured on this hardware |
|---|---|---|
| 1. Node death | Hard stop of the node holding the PostgreSQL primary | **1 failed request out of 4315 probes.** Node went NotReady in 40 s, CloudNativePG promoted the replica on its own, pods moved after the 300 s eviction toleration |
| 2. Broken deploy | Image tag that does not exist pushed to Git | **Zero downtime across 3437 probes.** The readiness probe froze the rollout, the old replicas kept serving, and a git revert had it back to 3 of 3 in 20 s |
| 3. Load spike | k6, 60 virtual users for five minutes | **924512 requests at 3081 req/s, p95 22.34 ms, zero failures.** The HPA went from 3 to 6 replicas in 40 s and back down 6 minutes after the load stopped |
| 4. Total loss | terraform destroy of all three nodes with the cluster live | **9 m 37 s** from destroy to three nodes in HA, 10 applications healthy, certificates reissued, PostgreSQL replicated and the data back from a 4 KB dump |

Every number above was measured, not estimated. The screenshots and the logs
behind them are in [docs/evidence.md](docs/evidence.md)

Each drill was run twice on purpose, which is the whole point of writing them
as scripts. The first pass finds what breaks, the second measures. Drill 4
found two real bugs on its first pass and neither was in the cluster: SSH
refused to talk to the rebuilt nodes because their host keys had changed, and
the ArgoCD install failed because one of its CRDs is larger than the 262144
bytes a Kubernetes annotation admits. Both are fixed in the script.

## The stack

| Layer | Tool | Why |
|---|---|---|
| Nodes | Terraform with the bpg Proxmox provider, privileged LXC containers | The cluster starts from a terraform apply, which is what makes drill 4 possible. They are containers and not VMs because nested virtualisation pushed etcd writes to 500-980 ms and the cluster ate itself in leader elections. See [docs/lab-notes.md](docs/lab-notes.md) |
| Cluster | k3s, three servers with embedded etcd | Real quorum. With one master you cannot kill the master and tell the story |
| Deployments | ArgoCD with an app of apps | If it is not in Git it does not exist. Rollback is a revert |
| Stateful workload | PostgreSQL with CloudNativePG | Primary and replica on different nodes with automatic failover |
| Stateless workload | podinfo with 3 replicas and an HPA | Built for demos of health probes and autoscaling |
| Ingress and TLS | Traefik plus cert-manager with DNS challenge | Real certificates on a private cluster, nothing exposed to the internet |
| Load balancing | MetalLB in L2 mode | LoadBalancer services on bare metal like a cloud would give you |
| Observability | kube-prometheus-stack | Alerts for dead nodes and crash loops routed to my usual channel |

## How to run it

```bash
# 1. Nodes (fill terraform.tfvars from the example first)
cd terraform && terraform init && terraform apply

# 2. Make the containers able to run k3s, from the Proxmox host
scripts/prepare-lxc.sh 201 202 203

# 3. k3s in HA over SSH. No Ansible needed, which matters if you drive
#    this from Windows like I do
IDENTITY=~/.ssh/id_lab scripts/install-k3s-ssh.sh 192.168.1.61 192.168.1.62 192.168.1.63 root

# 4. ArgoCD and the root app. Git does the rest.
#    --server-side is not optional: one ArgoCD CRD is over the 262144 byte
#    annotation limit and a client side apply fails on it
kubectl create namespace argocd
kubectl apply --server-side -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl apply -n argocd -f cluster/bootstrap/root-app.yaml

# 5. The two manual steps, both on purpose (see docs/setup-secrets.md)
kubectl apply --server-side -f https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.24/releases/cnpg-1.24.0.yaml
kubectl -n cert-manager create secret generic cloudflare-api-token --from-literal=api-token=YOUR_TOKEN
```

A full rebuild from step 1 to a cluster serving traffic again takes 9 minutes
and 37 seconds here, and [drills/drill4-total-loss.sh](drills/drill4-total-loss.sh)
does all of it unattended.

Then run the drills in [drills/](drills/) and fill the results table with what
your own hardware gives you.

## Honest scope

This lab does not recreate multi tenant RBAC at company scale, managed control planes or a service mesh. It recreates operations. Deploying, watching, breaking and recovering a small cluster end to end, with numbers instead of adjectives.

Versions are pinned everywhere on purpose. A lab without pinned versions breaks by itself in three months.
