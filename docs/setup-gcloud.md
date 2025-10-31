# Google Cloud Deployment Guide

Complete step-by-step guide for deploying the Miners Online Minecraft cluster to Google Cloud Platform (GCP) using Google Kubernetes Engine (GKE).

## Prerequisites

### Local Requirements

- Google Cloud SDK (`gcloud` CLI) installed and authenticated
- `kubectl` v1.27+ installed
- `helm` 3.x installed
- All tools properly configured and accessible from your terminal

### GCP Account Setup

1. Create or select a GCP project
2. Enable billing for your project
3. Ensure you have appropriate IAM permissions to:
   - Create GKE clusters
   - Manage Compute resources
   - Access Container Registry (if using custom images)

## Phase 1: GCP Project Configuration

### 1.1 Authenticate with Google Cloud

```bash
# Login to your Google Cloud account
gcloud auth login

# Set your default project (replace YOUR_PROJECT_ID with your actual project ID)
gcloud config set project YOUR_PROJECT_ID

# Verify project is set correctly
gcloud config get-value project
```

### 1.2 Enable Required APIs

```bash
# Enable Kubernetes Engine API
gcloud services enable container.googleapis.com

# Enable Compute Engine API
gcloud services enable compute.googleapis.com

# Enable Container Registry API (if using custom images)
gcloud services enable containerregistry.googleapis.com
```

### 1.3 Configure Default Region/Zone (Optional)

```bash
# Set default region (choose based on your needs: us-central1, europe-west1, asia-east1, etc.)
gcloud config set compute/region us-central1

# Set default zone
gcloud config set compute/zone us-central1-a
```

## Phase 2: Create GKE Cluster

### 2.1 Create the Cluster

Choose the appropriate command based on your requirements:

**Option A: Basic cluster with default settings**

```bash
gcloud container clusters create miners-online \
  --region us-central1 \
  --num-nodes 3 \
  --machine-type n1-standard-4
```

**Option B: Cluster with more configuration (Recommended for Production)**

```bash
gcloud container clusters create miners-online \
  --region us-central1 \
  --zone us-central1-a \
  --num-nodes 3 \
  --machine-type n1-standard-4 \
  --enable-ip-alias \
  --enable-stackdriver-kubernetes \
  --addons HttpLoadBalancing,HttpsLoadBalancing \
  --workload-pool=YOUR_PROJECT_ID.svc.id.goog \
  --enable-shielded-nodes
```

**Option C: Cluster with node auto-scaling**

```bash
gcloud container clusters create miners-online \
  --region us-central1 \
  --initial-node-count 3 \
  --machine-type n1-standard-4 \
  --enable-autoscaling \
  --min-nodes 1 \
  --max-nodes 10
```

### 2.2 Monitor Cluster Creation

The cluster creation process typically takes 5-10 minutes. You can monitor progress in:
- Google Cloud Console: [https://console.cloud.google.com/kubernetes/list](https://console.cloud.google.com/kubernetes/list)
- Terminal: Use `gcloud container clusters describe miners-online --region us-central1` to check status

### 2.3 Get Cluster Credentials

Once the cluster is created, configure `kubectl` to access it:

```bash
# Get credentials for your GKE cluster
gcloud container clusters get-credentials miners-online --region us-central1

# Verify connectivity to the cluster
kubectl cluster-info
kubectl get nodes
```

## Phase 3: Create Kubernetes Namespaces

Create the three required namespaces for your infrastructure:

```bash
# Create agones-system namespace
kubectl create namespace agones-system

# Create shulker-system namespace
kubectl create namespace shulker-system

# Create miners-online namespace for your Minecraft cluster
kubectl create namespace miners-online

# Verify namespaces are created
kubectl get namespaces
```

## Phase 4: Install Agones

Agones is the game server orchestration platform that manages your Minecraft servers.

### 4.1 Add Agones Helm Repository

```bash
# Add the official Agones Helm repository
helm repo add agones https://agones.dev/chart/stable

# Update Helm repositories
helm repo update

# Verify the repository was added
helm repo list
```

### 4.2 Install Agones with Shulker Configuration

```bash
# Install Agones version 1.52.0 with Shulker values
helm install agones agones/agones \
  --namespace agones-system \
  --version 1.52.0 \
  -f charts/agones/values-shulker.yaml

# Watch Agones pods until all are Running (takes 2-3 minutes)
kubectl -n agones-system get pods --watch
```

**Expected pods to see:**
- `agones-controller-*` - Main controller pod
- `agones-allocator-*` - Allocator pod
- `agones-webhook-*` - Webhook pod

Press `Ctrl+C` to stop watching once all pods are in `Running` state.

### 4.3 Verify Agones Installation

```bash
# Check all Agones pods are running
kubectl -n agones-system get pods

# Check Agones CRDs are installed
kubectl get crd | grep agones

# Verify allocator is accessible
kubectl -n agones-system get svc agones-allocator
```

## Phase 5: Install Shulker

Shulker is the Minecraft operator that manages MinecraftClusters, ProxyFleets, and MinecraftServerFleets.

### 5.1 Deploy Shulker Operator

```bash
# Apply the Shulker operator manifest from the official repository
kubectl apply -f https://raw.githubusercontent.com/jeremylvln/Shulker/main/kube/manifests/stable.yaml \
  -n shulker-system

# Watch Shulker pods until Running (takes 1-2 minutes)
kubectl -n shulker-system get pods --watch
```

Press `Ctrl+C` to stop watching once the Shulker operator pod is in `Running` state.

### 5.2 Verify Shulker Installation

```bash
# Check Shulker pod is running
kubectl -n shulker-system get pods

# Check Shulker CRDs are installed
kubectl get crd | grep shulker

# List available Shulker custom resources
kubectl api-resources | grep shulker
```

## Phase 6: Deploy Minecraft Infrastructure

### 6.1 Deploy Using Kustomize

Deploy your Minecraft cluster, proxy, and servers using the kustomize base configuration:

```bash
# Apply the kustomize base (includes cluster, proxy, and server manifests)
kubectl apply -k kustomize/base

# Monitor the deployment (this will take several minutes)
kubectl -n miners-online get pods --watch
```

Press `Ctrl+C` once the proxy and server pods are in `Running` or `Ready` state.

### 6.2 Verify Deployment

Verify all components are properly deployed:

```bash
# Check all pods in miners-online namespace
kubectl -n miners-online get pods

# Check MinecraftCluster resource
kubectl -n miners-online get minecraftclusters

# Check ProxyFleet (Velocity proxies)
kubectl -n miners-online get proxyfleets

# Check MinecraftServerFleet (Paper servers)
kubectl -n miners-online get minecraftserverfleets

# Check GameServers managed by Agones
kubectl -n miners-online get gameservers
```

### 6.3 View Detailed Resource Status

```bash
# Get detailed information about MinecraftCluster
kubectl -n miners-online describe minecraftcluster miners-online

# Get detailed information about ProxyFleet
kubectl -n miners-online describe proxyfleet proxy

# Get detailed information about MinecraftServerFleet
kubectl -n miners-online describe minecraftserverfleet lobby
```

## Phase 7: Access Your Minecraft Server

### 7.1 Get External IP Address

The Minecraft proxy is exposed via a LoadBalancer service that automatically gets assigned an external IP from GCP:

```bash
# Get the external IP of the public service
kubectl -n miners-online get service public -o wide

# Watch for the external IP to be assigned (may take 1-2 minutes)
kubectl -n miners-online get service public --watch
```

Look for the `EXTERNAL-IP` column. Once it shows an IP address instead of `<pending>`, your service is ready.

### 7.2 Retrieve the IP Address for Use

```bash
# Get the external IP in a variable (Linux/Mac)
PROXY_IP=$(kubectl -n miners-online get service public -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Minecraft Server: $PROXY_IP:25565"

# Get the external IP in a variable (PowerShell Windows)
$PROXY_IP = kubectl -n miners-online get service public -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
Write-Host "Minecraft Server: $PROXY_IP:25565"
```

### 7.3 Configure Firewall Rules (If Needed)

GKE automatically configures firewall rules for LoadBalancer services, but verify connectivity:

```bash
# Test connectivity to the Minecraft port from your local machine
# (if netcat or similar tools are available)
nc -zv YOUR_EXTERNAL_IP 25565
```

### 7.4 Connect from Minecraft Client

1. Open Minecraft Java Edition
2. Click "Multiplayer"
3. Click "Add Server"
4. Enter the server details:
   - **Server Name**: Miners Online (or any name you prefer)
   - **Server Address**: `YOUR_EXTERNAL_IP:25565` (use the IP from Phase 7.1)
5. Click "Done"
6. Select your server and click "Join Server"

## Phase 8: Post-Deployment Configuration

### 8.1 Persistent Storage (Optional)

If your servers need persistent storage (e.g., for world data, player data):

```bash
# Create a Google Cloud Storage bucket
gsutil mb gs://miners-online-data

# Or use persistent volumes with GCP storage classes
kubectl describe storageclass standard-rwo
```

### 8.2 Monitoring and Logging

Enable Google Cloud Monitoring and Logging integration:

```bash
# View logs in Cloud Logging
# Navigate to Logs Explorer in Google Cloud Console
# Filter by: resource.type="k8s_container" AND resource.labels.namespace_name="miners-online"

# View metrics in Cloud Monitoring
# Navigate to Metrics Explorer in Google Cloud Console
# Select Kubernetes container metrics

# View pod logs directly
kubectl -n miners-online logs -f deployment/proxy

# View server logs
kubectl -n miners-online logs -f gameserver/lobby-0
```

### 8.3 Set Up Autoscaling (Optional)

Configure automatic scaling of nodes based on resource demand:

```bash
# Update cluster autoscaling settings
gcloud container clusters update miners-online \
  --region us-central1 \
  --enable-autoscaling \
  --min-nodes 1 \
  --max-nodes 10

# Configure horizontal pod autoscaling for servers (if desired)
kubectl autoscale deployment lobby --cpu-percent=80 --min=2 --max=10 -n miners-online
```

### 8.4 Configure Backup Strategy

```bash
# Create a backup storage location
gsutil mb gs://miners-online-backups

# Set up scheduled backups for persistent data
# This should be configured based on your specific storage backend
```

## Troubleshooting

### Common Issues and Solutions

**Issue: Pods are stuck in `Pending` state**

```bash
# Check pod events for more information
kubectl -n miners-online describe pod <pod-name>

# Check node resources
kubectl describe nodes

# Check if there are enough resources in the cluster
kubectl top nodes
```

**Issue: LoadBalancer service doesn't get an external IP**

```bash
# Check service status
kubectl -n miners-online describe service public

# Check if service has a load balancer configured
kubectl -n miners-online get service public -o yaml

# View service events
kubectl -n miners-online get events --sort-by='.lastTimestamp'
```

**Issue: Agones or Shulker pods not running**

```bash
# Check pod logs
kubectl -n agones-system logs <pod-name>
kubectl -n shulker-system logs <pod-name>

# Check for resource constraints
kubectl top nodes
kubectl describe nodes
```

**Issue: Can't connect to Minecraft server**

```bash
# Verify proxy pod is running and ready
kubectl -n miners-online get pods -l app=proxy

# Check proxy logs
kubectl -n miners-online logs -f deployment/proxy

# Verify LoadBalancer service has external IP
kubectl -n miners-online get service public

# Test network connectivity
telnet YOUR_EXTERNAL_IP 25565
```

### Useful Debugging Commands

```bash
# View all events in miners-online namespace
kubectl -n miners-online get events --sort-by='.lastTimestamp'

# Check cluster autoscaler status
gcloud container clusters describe miners-online --region us-central1

# View GKE cluster in console
gcloud container clusters describe miners-online --region us-central1 --format="table(status, masterStatus)"

# Check GKE operations
gcloud container operations list

# View resource quotas
kubectl describe resourcequota -n miners-online
```

## Cleanup and Teardown

When you're ready to shut down your Minecraft cluster:

### Remove Minecraft Resources

```bash
# Delete Minecraft manifests
kubectl delete -k kustomize/base

# Wait for resources to clean up (may take 1-2 minutes)
kubectl -n miners-online get all
```

### Uninstall Shulker

```bash
# Delete Shulker operator
kubectl delete -f https://raw.githubusercontent.com/jeremylvln/Shulker/main/kube/manifests/stable.yaml -n shulker-system

# Delete shulker-system namespace
kubectl delete namespace shulker-system
```

### Uninstall Agones

```bash
# Uninstall Agones Helm release
helm uninstall agones -n agones-system

# Delete agones-system namespace
kubectl delete namespace agones-system
```

### Delete GKE Cluster

```bash
# Delete the entire GKE cluster (WARNING: This is permanent)
gcloud container clusters delete miners-online --region us-central1

# Confirm deletion when prompted
```

### Clean Up GCP Resources

```bash
# Delete storage buckets (if created)
gsutil rm -r gs://miners-online-data
gsutil rm -r gs://miners-online-backups

# Delete any persistent disks (if created)
gcloud compute disks list
gcloud compute disks delete <disk-name> --zone us-central1-a
```

## Cost Optimization Tips

1. **Use preemptible nodes** for cost savings (suitable for game servers):
   ```bash
   gcloud container clusters create miners-online \
     --preemptible \
     --num-nodes 3 \
     --region us-central1
   ```

2. **Use smaller machine types** during testing and scale up for production

3. **Monitor costs** in the Google Cloud Console under Billing

4. **Set up budget alerts** to receive notifications if spending exceeds thresholds

5. **Use committed use discounts** for long-term deployments

## Next Steps

- [Configure CI/CD pipeline](./cicd-setup.md) for automated deployments
- [Monitor cluster health](./monitoring.md) with Cloud Monitoring
- [Configure backups](./backup-strategy.md) for data protection
- [Scale your infrastructure](./scaling.md) as needed
- Review [Shulker documentation](https://shulker.jeremylvln.fr/) for advanced configurations
- Review [Agones documentation](https://agones.dev/site/docs/) for game server tuning

## References

- [GKE Documentation](https://cloud.google.com/kubernetes-engine/docs)
- [Shulker Documentation](https://shulker.jeremylvln.fr/)
- [Agones Documentation](https://agones.dev/site/docs/)
- [Google Cloud Pricing](https://cloud.google.com/pricing)
