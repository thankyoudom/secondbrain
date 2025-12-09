---
title: KubernetesSeconBrain
tags: [zk]
---

# KubernetesSeconBrain
# GCP Deployment Guide

Deploy SecondBrain to Google Cloud Platform with K3s for increased compute resources.

## Prerequisites

- GCP account with billing enabled
- `gcloud` CLI installed and configured
- Local SecondBrain project ready

## 1. Create GCP VM

```bash
gcloud compute instances create secondbrain-k3s \
  --machine-type=e2-standard-4 \
  --zone=us-central1-a \
  --image-family=ubuntu-2204-lts \
  --image-project=ubuntu-os-cloud \
  --project=secondbrain \
  --boot-disk-size=200GB
```

**Specs:**
- Machine: e2-standard-4 (4 vCPUs, 16GB RAM)
- OS: Ubuntu 22.04 LTS
- Disk: 200GB
- Cost: ~$125/month if running 24/7

## 2. Connect to VM

### Via GCP Console

1. Go to Compute Engine → VM Instances
2. Find `secondbrain-k3s`
3. Click **SSH** button

### Via Terminal

```bash
gcloud compute ssh secondbrain-k3s --zone=us-central1-a
```

## 3. Install Software on VM

### Install K3s

```bash
curl -sfL https://get.k3s.io | sh -
sleep 30
sudo k3s kubectl get nodes
```

Wait until node shows **Ready** status.

### Install Docker

```bash
sudo apt update
sudo apt install -y docker.io
sudo usermod -aG docker $USER
newgrp docker
```

## 4. Transfer Files

On your **local machine** (new terminal):

```bash
# Navigate to project directory
cd /path/to/your/secondbrain/project

# Copy configuration files
gcloud compute scp docker-compose.yml Dockerfile secondbrain-k3s:~/ \
  --zone=us-central1-a

# Copy scripts (if you have any)
gcloud compute scp --recurse scripts/ secondbrain-k3s:~/scripts/ \
  --zone=us-central1-a

# Copy your notes
gcloud compute scp --recurse ~/SecondBrain secondbrain-k3s:~/ \
  --zone=us-central1-a
```

This may take a few minutes depending on your SecondBrain folder size.

## 5. Build Docker Image

Back in your **GCP SSH session**:

```bash
cd ~
docker build -t secondbrain-docker:latest .

# Import image into k3s
docker save secondbrain-docker:latest | sudo k3s ctr images import -
```

## 6. Create Kubernetes Configuration

Create deployment file:

```bash
cat > ~/k8s-deploy.yaml << 'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: secondbrain
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ollama-data
  namespace: secondbrain
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 50Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ollama
  namespace: secondbrain
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ollama
  template:
    metadata:
      labels:
        app: ollama
    spec:
      containers:
      - name: ollama
        image: ollama/ollama:latest
        ports:
        - containerPort: 11434
        volumeMounts:
        - name: ollama-data
          mountPath: /root/.ollama
        resources:
          limits:
            memory: "12Gi"
          requests:
            memory: "4Gi"
      volumes:
      - name: ollama-data
        persistentVolumeClaim:
          claimName: ollama-data
---
apiVersion: v1
kind: Service
metadata:
  name: ollama
  namespace: secondbrain
spec:
  selector:
    app: ollama
  ports:
  - port: 11434
    targetPort: 11434
  type: ClusterIP
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secondbrain
  namespace: secondbrain
spec:
  replicas: 1
  selector:
    matchLabels:
      app: secondbrain
  template:
    metadata:
      labels:
        app: secondbrain
    spec:
      containers:
      - name: secondbrain
        image: secondbrain-docker:latest
        imagePullPolicy: Never
        env:
        - name: OLLAMA_HOST
          value: "http://ollama:11434"
        - name: OLLAMA_NUM_PARALLEL
          value: "1"
        - name: OLLAMA_MAX_LOADED_MODELS
          value: "1"
        - name: OLLAMA_KEEP_ALIVE
          value: "5m"
        resources:
          limits:
            memory: "2Gi"
          requests:
            memory: "800Mi"
        stdin: true
        tty: true
        command: ["/bin/bash"]
        volumeMounts:
        - name: secondbrain-data
          mountPath: /home/dev/SecondBrain
      volumes:
      - name: secondbrain-data
        hostPath:
          path: /home/$USER/SecondBrain
          type: Directory
EOF
```

## 7. Deploy to K3s

```bash
# Apply configuration
sudo k3s kubectl apply -f k8s-deploy.yaml

# Watch pods start (takes 1-2 minutes)
sudo k3s kubectl get pods -n secondbrain -w
```

Press **Ctrl+C** when both pods show `Running` and `1/1` ready.

## 8. Access Your SecondBrain

```bash
# Get pod name
POD_NAME=$(sudo k3s kubectl get pod -n secondbrain -l app=secondbrain \
  -o jsonpath='{.items[0].metadata.name}')

# Connect interactively
sudo k3s kubectl exec -it -n secondbrain $POD_NAME -- /bin/bash
```

You're now inside your SecondBrain environment! 🎉

## 9. Verify Everything Works

Inside the container:

```bash
# Test Ollama connection
curl http://ollama:11434/api/tags

# Check your files are mounted
ls ~/SecondBrain

# Start working
vim
```

## Useful Management Commands

### Check Status

```bash
# Pod status
sudo k3s kubectl get pods -n secondbrain

# View logs
sudo k3s kubectl logs -n secondbrain -l app=ollama
sudo k3s kubectl logs -n secondbrain -l app=secondbrain
```

### Reconnect Anytime

```bash
sudo k3s kubectl exec -it -n secondbrain \
  $(sudo k3s kubectl get pod -n secondbrain -l app=secondbrain \
  -o jsonpath='{.items[0].metadata.name}') -- /bin/bash
```

### Update Deployment

```bash
# After making changes to k8s-deploy.yaml
sudo k3s kubectl apply -f k8s-deploy.yaml
```

### Cleanup

```bash
# Delete deployment
sudo k3s kubectl delete -f k8s-deploy.yaml

# Delete namespace (removes everything)
sudo k3s kubectl delete namespace secondbrain
```

## Troubleshooting

### Pods not starting

```bash
# Check pod details
sudo k3s kubectl describe pod -n secondbrain <pod-name>

# Check events
sudo k3s kubectl get events -n secondbrain
```

### Ollama connection issues

```bash
# Check Ollama service
sudo k3s kubectl get svc -n secondbrain

# Test from SecondBrain pod
curl http://ollama.secondbrain.svc.cluster.local:11434/api/tags
```

### Out of memory

If Ollama crashes, you may need to:
1. Use a smaller model (e.g., Phi-3 instead of Mistral)
2. Upgrade to a larger VM instance
3. Adjust memory limits in k8s-deploy.yaml

## Cost Optimization

To save costs:

```bash
# Stop VM when not in use
gcloud compute instances stop secondbrain-k3s --zone=us-central1-a

# Start when needed
gcloud compute instances start secondbrain-k3s --zone=us-central1-a
```

Only pay for disk storage (~$20/month) when stopped.
