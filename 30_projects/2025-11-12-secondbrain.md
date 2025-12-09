---
title: SecondBrain
tags: [secondbrain]
---

# SecondBrain

# SecondBrain Project

A containerized Zettelkasten environment with AI-powered grammar assistance, running on GCP with K3s.

## Overview

This project combines:
- **Zettelkasten note-taking** with `zk` and Neovim
- **Local LLM** via Ollama for grammar cleanup (like Grammarly)
- **Containerization** with Docker for portability
- **K3s deployment** on GCP for increased compute resources

## Architecture

```
┌─────────────────────────────────────────┐
│         GCP VM (e2-standard-4)          │
│  ┌───────────────────────────────────┐  │
│  │          K3s Cluster              │  │
│  │  ┌──────────┐    ┌─────────────┐ │  │
│  │  │ Ollama   │◄───┤ SecondBrain │ │  │
│  │  │ Service  │    │  Container  │ │  │
│  │  └──────────┘    └─────────────┘ │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

## Quick Start

### Local Development

```bash
# Start Docker environment (macOS with Colima)
colima start --mount $HOME:w --dns 8.8.8.8

# Build container
docker build -t dev-env .

# Run with volumes
docker run -it --rm \
  -v ~/SecondBrain:/home/dev/SecondBrain \
  -v ~/.vimrc:/home/dev/.vimrc \
  -v ~/.vim:/home/dev/.vim \
  dev-env
```

### GCP Deployment

See [deployment guide](./docs/deployment.md) for full instructions.

## Project Structure

```
secondbrain/
├── Dockerfile              # Container definition
├── docker-compose.yml      # Local multi-container setup
├── k8s-deploy.yaml        # Kubernetes deployment config
├── scripts/               # Helper scripts
└── SecondBrain/          # Your notes (mounted volume)
```

## Features

- **Atomic note-taking** with Zettelkasten methodology
- **Vim/Neovim** keyboard-driven workflow
- **AI grammar assistance** via Ollama (Mistral/LLaMA models)
- **Portable environment** runs anywhere Docker runs
- **Cloud deployment** for heavy AI workloads

## Documentation

- [Workflow Guide](./docs/workflow.md) - Daily usage patterns
- [Command Reference](./docs/commands.md) - All commands and shortcuts
- [Deployment Guide](./docs/deployment.md) - GCP setup instructions

## Why This Setup?

1. **Reproducible** - Same environment everywhere
2. **Scalable** - Move to cloud when you need more compute
3. **Private** - Your notes + AI run locally/self-hosted
4. **Portfolio-ready** - Demonstrates Docker, K8s, LLM integration
