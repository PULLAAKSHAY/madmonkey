#!/bin/bash

###############################################
# 1. System Update & Basic Dependencies
###############################################
sudo apt update && sudo apt upgrade -y
sudo apt install -y ca-certificates curl gnupg lsb-release apt-transport-https


###############################################
# 2. Install Docker CE (Latest Stable)
###############################################
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

sudo systemctl enable --now docker
docker --version


###############################################
# 3. Configure containerd (Kubernetes Runtime)
###############################################
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml >/dev/null

# Use the recommended cgroup driver
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

sudo systemctl restart containerd
sudo systemctl enable containerd


###############################################
# 4. Disable Swap (Kubernetes requirement)
###############################################
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab


###############################################
# 5. Kernel Networking Modules for K8s
###############################################
cat <<'EOF' | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system


###############################################
# 6. Install Kubernetes v1.30.x (KIND-Compatible)
###############################################
sudo install -m 0755 -d /etc/apt/keyrings

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | \
    sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes.gpg

echo \
  "deb [signed-by=/etc/apt/keyrings/kubernetes.gpg] \
  https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" | \
  sudo tee /etc/apt/sources.list.d/kubernetes.list > /dev/null

sudo apt update
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

sudo systemctl enable --now kubelet


###############################################
# 7. Verify Versions
###############################################
echo "Docker: $(docker --version)"
echo "containerd: $(containerd --version)"
echo "kubeadm: $(kubeadm version)"
echo "kubelet: $(kubelet --version)"
echo "kubectl: $(kubectl version --client)"


###############################################
# 8. Install KIND (v0.23.0)
###############################################
curl -Lo kind https://kind.sigs.k8s.io/dl/v0.23.0/kind-linux-amd64
chmod +x kind
sudo mv kind /usr/local/bin/

echo "KIND: $(kind --version)"

echo ""
echo "======================================================"
echo "Setup Complete! KIND-Compatible Kubernetes v1.30 Ready"
echo "Use this to create a cluster:"
echo 'kind create cluster --config kind-multinode.yaml --image kindest/node:v1.30.0'
echo "======================================================"
