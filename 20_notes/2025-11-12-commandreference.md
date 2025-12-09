---
title: CommandReference
tags: [zk]
---

# CommandReference

# Command Reference

Quick reference for SecondBrain workflows.

## Zettelkasten (zk)

### Core Commands

```bash
# Create new note
zk new "Note title"
zk new --title "maybellama" 00_inbox --extra tags="test" --template note.md

# Daily note
zk new --template daily.md "$(date +%Y-%m-%d)"

# List recent notes
zk list --sort created- --limit 10

# Search content
zk grep "keyword"

# Interactive picker (fuzzy search)
zk edit --interactive

# Tag management
zk tag list
zk tag find devops

# Show backlinks
zk backlinks

# Rebuild index
zk index
```

### Workflow

```bash
# Navigate to SecondBrain
cd ~/SecondBrain

# Create and edit new note
zk new "Cloud Monitoring Practice" --edit nvim

# Open most recent note
nvim $(zk list --sort created- --limit 1 --path-only)
```

## Vim/Neovim Essentials

### Navigation

| Command | Action |
|---------|--------|
| `Esc` | Normal mode |
| `i` | Insert before cursor |
| `a` | Append after cursor |
| `o` | New line below |
| `gg` | Top of file |
| `G` | Bottom of file |
| `/keyword` | Search |
| `n` / `N` | Next/previous result |

### Editing

| Command | Action |
|---------|--------|
| `dd` | Delete line |
| `yy` | Copy line |
| `p` | Paste |
| `u` | Undo |
| `Ctrl+r` | Redo |
| `:%s/old/new/g` | Replace all |

### File Operations

| Command | Action |
|---------|--------|
| `:w` | Save |
| `:q` | Quit |
| `:wq` | Save and quit |
| `:q!` | Quit without saving |

### Visual Mode

| Command | Action |
|---------|--------|
| `v` | Select text |
| `y` | Copy selection |
| `d` | Delete selection |
| `>` | Indent |

## Docker Commands

### Local Development

```bash
# Build image
docker build -t dev-env .
docker build --no-cache -t dev-env .  # Force rebuild

# Run container
docker run -it --rm dev-env

# Run with volumes mounted
docker run -it --rm \
  -v ~/SecondBrain:/home/dev/SecondBrain \
  -v ~/.vimrc:/home/dev/.vimrc \
  -v ~/.vim:/home/dev/.vim \
  -v ~/.tmux.conf:/home/dev/.tmux.conf \
  -v ~/.config:/home/dev/.config \
  dev-env

# Docker Compose
docker-compose up -d
docker-compose down
docker exec -it secondbrain-docker bash

# Cleanup
docker system prune -af
```

### Colima (macOS)

```bash
# Start
colima start --mount $HOME:w --dns 8.8.8.8 --network-address
docker context use colima

# Management
colima status
colima stop
colima restart
colima delete
colima list
```

## Kubernetes (K3s)

### Pod Management

```bash
# Get pods
sudo k3s kubectl get pods -n secondbrain

# Watch pod status
sudo k3s kubectl get pods -n secondbrain -w

# View logs
sudo k3s kubectl logs -n secondbrain -l app=ollama
sudo k3s kubectl logs -n secondbrain -l app=secondbrain

# Connect to container
POD_NAME=$(sudo k3s kubectl get pod -n secondbrain -l app=secondbrain -o jsonpath='{.items[0].metadata.name}')
sudo k3s kubectl exec -it -n secondbrain $POD_NAME -- /bin/bash
```

### Deployment

```bash
# Apply configuration
sudo k3s kubectl apply -f k8s-deploy.yaml

# Check nodes
sudo k3s kubectl get nodes
```

## GCP Commands

### VM Management

```bash
# SSH into VM
gcloud compute ssh secondbrain-k3s --zone=us-central1-a

# Copy files to VM
gcloud compute scp docker-compose.yml Dockerfile secondbrain-k3s:~/ --zone=us-central1-a
gcloud compute scp --recurse ~/SecondBrain secondbrain-k3s:~/ --zone=us-central1-a
```

## Ollama

### Inside Container

```bash
# Test Ollama connection
curl http://ollama:11434/api/tags

# Pull model
ollama pull mistral

# Run model
ollama run mistral
```

## Daily Workflow

```bash
# 1. Navigate to SecondBrain
cd ~/SecondBrain

# 2. Create daily note
zk new "$(date +%Y-%m-%d) Daily" --template daily.md

# 3. Edit in Neovim
nvim $(zk list --sort created- --limit 1 --path-only)

# 4. Write atomic note with links
# Inside vim: [[Link to other notes]] #tags

# 5. Review recent notes
zk list --sort created- --limit 20
```
