# Manual Deployment Steps

## 1. Create Kubernetes Cluster

#### Option A: kind (Local Testing)

```bash
kind create cluster --name miners-online
```

#### Option B: Minikube (Local Testing)

```bash
minikube start --cpus=4 --memory=8192
```

## 2. Install Agones

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

## 3. Install Shulker

Apply the Shulker operator (pre-rendered manifest from official repo):

```bash
# Apply Shulker operator
kubectl apply -f https://raw.githubusercontent.com/jeremylvln/Shulker/main/kube/manifests/stable.yaml \
  -n shulker-system

# Verify Shulker pods are running
kubectl -n shulker-system get pods --watch
```

Wait for Shulker operator pod to reach `Running` state.

## 4. Deploy Minecraft Cluster

Create the dedicated `miners-online` namespace and apply the Shulker cluster, proxy, and server manifests:

```bash
# Create dedicated namespace for Minecraft resources
kubectl create namespace miners-online

# Apply manifests (for cloud deployments with LoadBalancer support)
kubectl apply -f kustomize/base/manifests/shulker/cluster.yaml
kubectl apply -f kustomize/base/manifests/shulker/proxy.yaml
kubectl apply -f kustomize/base/manifests/shulker/lobby.yaml

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

## 5. Verify Deployment

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

## 6. Connect to Minecraft Server

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

## Cleanup

```bash
# Delete Minecraft resources
kubectl delete -f kustomize/base/manifests/shulker/lobby.yaml
kubectl delete -f kustomize/base/manifests/shulker/proxy.yaml
kubectl delete -f kustomize/base/manifests/shulker/cluster.yaml

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
