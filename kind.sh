#!/bin/sh
set -o errexit

# create registry container unless it already exists
reg_name='registry-local'
reg_port='5000'
running="$(docker inspect -f '{{.State.Running}}' "${reg_name}" 2>/dev/null || true)"
if [ "${running}" != 'true' ]; then
  docker run \
    -d --restart=always -p "127.0.0.1:${reg_port}:5000" --name "${reg_name}" \
    registry:2
fi

# create a cluster with the local registry enabled in containerd
cat <<EOF | kind create cluster --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:${reg_port}"]
    endpoint = ["http://${reg_name}:5000"]
EOF

# connect the registry to the cluster network
# (the network may already be connected)
docker network connect "kind" "${reg_name}" || true

# Document the local registry
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:${reg_port}"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF

# Allow me to pull docker hub images directly

socure_bundle_cert='~/Downloads/FW_BUNDLE.crt'
control_plane='kind-control-plane'
docker cp ${socure_bundle_cert} ${control_plane}:/usr/local/share/ca-certificates/  
docker exec ${control_plane} update-ca-certificates        

docker stop ${control_plane} && docker start ${control_plane} && docker exec ${control_plane} sh -c 'mount -o remount,ro /sys; kill -USR1 1'

