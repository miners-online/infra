# Troubleshooting

## Agones pod stuck in CrashLoopBackOff

```bash
# Check logs
kubectl -n agones-system logs -l app=agones-controller

# Ensure webhook admissions are enabled
kubectl api-resources | grep mutatingwebhookconfigurations
```

## Shulker pod stuck in ContainerCreating (missing allocator-client secret)

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

## Shulker pod not starting (other issues)

```bash
# Check if Agones is ready and shulker-system is in gameservers.namespaces
kubectl get crd gameservers.agones.dev
kubectl -n shulker-system logs -l app.kubernetes.io/name=shulker
```

## Minecraft server Pod not running

```bash
# Check Agones GameServer status
kubectl -n shulker-system describe gameserver

# Check Shulker server logs
kubectl -n shulker-system logs -l app=minecraftserver
```

## LoadBalancer stuck in "Pending" on local cluster

This is expected for kind. Use the kind overlay:
```bash
kubectl apply -k kustomize/overlays/kind
kubectl -n shulker-system port-forward svc/public 25565:25565
```

## Pods not starting due to ImagePullBackOff / ErrImagePull

This usually indicates that the container image cannot be pulled from the registry. We can fix by pulling the images manually:

```bash
docker pull alpine:latest
docker pull redis:7-alpine
```

and then restarting the pods:

```bash
kubectl -n miners-online delete pod <pod-name>
```