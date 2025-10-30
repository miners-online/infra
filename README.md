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

## References

- [Shulker Documentation](https://shulker.jeremylvln.fr/)
- [Agones Documentation](https://agones.dev/site/docs/)
- [Kubernetes Operator Pattern](https://kubernetes.io/docs/concepts/extend-kubernetes/operator/)
