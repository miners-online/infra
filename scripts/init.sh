kubectl create namespace shulker-system

helm repo add agones https://agones.dev/chart/stable
helm repo update

helm install agones agones/agones \
  --namespace agones-system \
  --create-namespace \
  --version 1.52.0 \
  -f charts/agones/values-shulker.yaml

kubectl apply -f https://raw.githubusercontent.com/jeremylvln/Shulker/main/kube/manifests/stable.yaml \
  -n shulker-system

kubectl create namespace miners-online
