# Miners Online Kubernetes Infrastructure

Production-ready Kubernetes cluster configuration for Shulker (Minecraft operator) and Agones (game server orchestration).

## Prerequisites

- Kubernetes cluster (v1.27+): GKE, AKS, EKS, kind, or Minikube
- `kubectl` configured and authenticated to your cluster
- `helm` 3.x installed
- For local testing: `kind` or `minikube`

## Versions

- **Agones**: 1.52.0 ([Release Notes](https://github.com/googleforgames/agones/releases/tag/release-1.52.0))
- **Shulker**: main branch / latest stable ([GitHub](https://github.com/jeremylvln/Shulker))

## Architecture

```
┌─────────────────────────────────────────┐
│     Kubernetes Cluster (1.27+)          │
├─────────────────────────────────────────┤
│ ┌─────────────────┐  ┌────────────────┐ │
│ │  agones-system  │  │ shulker-system │ │
│ ├─────────────────┤  ├────────────────┤ │
│ │ • Controller    │  │ • Operator     │ │
│ │ • Webhook       │  │ • Proxy API    │ │
│ │ • Allocator     │  │ • Server Mgmt  │ │
│ │ (GameServers)   │  │                │ │
│ └─────────────────┘  └────────────────┘ │
│                                         │
│ ┌─────────────────────────────────────┐ │
│ │     miners-online (Minecraft)       │ │
│ ├─────────────────────────────────────┤ │
│ │ • ProxyFleets (Velocity proxies)    │ │
│ │ • MinecraftServers (Paper servers)  │ │
│ │ • GameServers (managed by Agones)   │ │
│ └─────────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

**Namespace Separation:**
- `agones-system` — Agones game server orchestration platform
- `shulker-system` — Shulker operator and management components
- `miners-online` — Minecraft cluster resources (proxies, servers, game logic)

## Manual Deployment Steps

### 1. Create Kubernetes Cluster

#### Option A: GKE (Google Cloud)

```bash
gcloud container clusters create miners-online \
  --zone us-central1-a \
  --num-nodes 3 \
  --machine-type n1-standard-2 \
  --enable-ip-alias
```

#### Option B: kind (Local Testing)

```bash
kind create cluster --name miners-online
```

#### Option C: Minikube (Local Testing)

```bash
minikube start --cpus=4 --memory=8192
```

### 2. Install Agones

Add the Agones Helm repository and install with Shulker-compatible values:

```bash
# Create namespace
kubectl create namespace shulker-system

# Add Agones repo
helm repo add agones https://agones.dev/chart/stable
helm repo update

# Install Agones (pinned to 1.52.0) with Shulker values
helm install agones agones/agones \
  --namespace agones-system \
  --create-namespace \
  --version 1.52.0 \
  -f charts/agones/values-shulker.yaml

# Verify Agones pods are running
kubectl -n agones-system get pods --watch
```

Wait for all Agones pods to reach `Running` state (typically 2-3 minutes).

### 3. Install Shulker

Apply the Shulker operator (pre-rendered manifest from official repo):

```bash
# Apply Shulker operator
kubectl apply -f https://raw.githubusercontent.com/jeremylvln/Shulker/main/kube/manifests/stable.yaml \
  -n shulker-system

# Verify Shulker pods are running
kubectl -n shulker-system get pods --watch
```

Wait for Shulker operator pod to reach `Running` state.

### 4. Deploy Minecraft Cluster

Create the dedicated `miners-online` namespace and apply the Shulker cluster, proxy, and server manifests:

```bash
# Create dedicated namespace for Minecraft resources
kubectl create namespace miners-online

# Apply manifests (for cloud deployments with LoadBalancer support)
kubectl apply -f manifests/shulker/cluster.yaml
kubectl apply -f manifests/shulker/proxy.yaml
kubectl apply -f manifests/shulker/lobby.yaml

# Verify resources are created
kubectl -n miners-online get minecraftclusters
kubectl -n miners-online get proxyfleets
kubectl -n miners-online get minecraftserverfleets
```

Or, use **kustomize** for parameterized deployments:

```bash
# For cloud clusters (with LoadBalancer)
kubectl apply -k kustomize/base

# For kind/local clusters (converts LoadBalancer to ClusterIP)
kubectl apply -k kustomize/overlays/kind
```

### 5. Verify Deployment

```bash
# Check all pods in all namespaces
kubectl get pods -n agones-system
kubectl get pods -n shulker-system
kubectl get pods -n miners-online

# Check Agones GameServers (created by Shulker for Minecraft workloads)
kubectl get gameservers -n miners-online

# Check Shulker Minecraft resources
kubectl get minecraftcluster -n miners-online
kubectl get proxyfleet -n miners-online
kubectl get minecraftserverfleet -n miners-online

# Get the proxy service endpoint (cloud deployments)
kubectl -n miners-online get service public -o wide

# For kind/local: port-forward to the proxy
kubectl -n miners-online port-forward svc/public 25565:25565 &
```

### 6. Connect to Minecraft Server

Once the proxy and server pods are running:

**Cloud deployments** (LoadBalancer):
```bash
# Get the external IP
PROXY_IP=$(kubectl -n miners-online get service public -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Add to Minecraft: $PROXY_IP:25565"
```

**Local deployments** (kind/port-forward):
```bash
# Proxy is available at localhost:25565
echo "Add to Minecraft: localhost:25565"
```

Then open Minecraft and connect to the server address.

## Directory Structure

```
miners-online/infra/
├── manifests/
│   └── shulker/             # Shulker CRs (deployed via kubectl)
│       ├── cluster.yaml     # MinecraftCluster definition
│       ├── proxy.yaml       # ProxyFleet definition
│       └── lobby.yaml       # MinecraftServerFleet definition
├── kustomize/
│   ├── base/                # Kustomize base (references manifests/shulker/)
│   │   └── kustomization.yaml
│   └── overlays/
│       └── kind/            # Overlay for kind (converts LoadBalancer→ClusterIP)
│           └── kustomization.yaml
├── charts/
│   └── agones/
│       └── values-shulker.yaml  # Helm values for Agones (used during helm install)
└── README.md
```

### File Locations

- **Agones**: Installed via Helm using `charts/agones/values-shulker.yaml`
- **Shulker**: Deployed via kubectl using manifests in `manifests/shulker/`
- **Kustomize**: Base and overlays reference Shulker manifests for repeatable deployments

## Troubleshooting

### Agones pod stuck in CrashLoopBackOff

```bash
# Check logs
kubectl -n agones-system logs -l app=agones-controller

# Ensure webhook admissions are enabled
kubectl api-resources | grep mutatingwebhookconfigurations
```

### Shulker pod stuck in ContainerCreating (missing allocator-client secret)

The Shulker operator requires the Agones allocator client TLS secret to be present in the `shulker-system` namespace. If the secret is missing:

1. **Uninstall Agones** and reinstall with corrected values:
```bash
helm uninstall agones -n agones-system
kubectl delete namespace agones-system

# Reinstall with corrected values (includes allocator client secret creation)
helm repo add agones https://agones.dev/chart/stable
helm install agones agones/agones \
  --namespace agones-system \
  --create-namespace \
  --version 1.52.0 \
  -f charts/agones/values-shulker.yaml

# Wait for Agones to be ready
kubectl -n agones-system get pods --watch
```

2. **Restart Shulker operator** to pick up the newly created secret:
```bash
kubectl rollout restart deployment/shulker-operator -n shulker-system
kubectl -n shulker-system get pods --watch
```

3. **Verify the secret exists in shulker-system**:
```bash
kubectl get secret allocator-client-ca -n shulker-system
```

### Shulker pod not starting (other issues)

```bash
# Check if Agones is ready and shulker-system is in gameservers.namespaces
kubectl get crd gameservers.agones.dev
kubectl -n shulker-system logs -l app.kubernetes.io/name=shulker
```

### Minecraft server Pod not running

```bash
# Check Agones GameServer status
kubectl -n shulker-system describe gameserver

# Check Shulker server logs
kubectl -n shulker-system logs -l app=minecraftserver
```

### LoadBalancer stuck in "Pending" on local cluster

This is expected for kind. Use the kind overlay:
```bash
kubectl apply -k kustomize/overlays/kind
kubectl -n shulker-system port-forward svc/public 25565:25565
```

### Pods not starting due to ImagePullBackOff / ErrImagePull

This usually indicates that the container image cannot be pulled from the registry. We can fix by pulling the images manually:

```bash
docker pull alpine:latest
docker pull redis:7-alpine
```

and then restarting the pods:

```bash
kubectl -n miners-online delete pod <pod-name>
```

## Cleanup

```bash
# Delete Minecraft resources
kubectl delete -f manifests/shulker/lobby.yaml
kubectl delete -f manifests/shulker/proxy.yaml
kubectl delete -f manifests/shulker/cluster.yaml

# Wait for resources to drain (~1 minute)
kubectl -n miners-online get all

# Delete the miners-online namespace
kubectl delete namespace miners-online

# Uninstall Shulker
kubectl delete -f https://raw.githubusercontent.com/jeremylvln/Shulker/main/kube/manifests/stable.yaml -n shulker-system
kubectl delete namespace shulker-system

# Uninstall Agones
helm uninstall agones -n agones-system
kubectl delete namespace agones-system

# Delete cluster (if using kind/minikube)
kind delete cluster --name miners-online
# or
minikube delete
```

## References

- [Shulker Documentation](https://shulker.jeremylvln.fr/)
- [Agones Documentation](https://agones.dev/site/docs/)
- [Kubernetes Operator Pattern](https://kubernetes.io/docs/concepts/extend-kubernetes/operator/)
