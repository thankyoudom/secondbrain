---
title: You're absolutely right—tech stack decisions, especially in the cloud…
date: 2025-08-12
source-folder: Notes
tags: [:needs-review: :has-attachments:]
review-reasons: has-attachments
---

# You're absolutely right—tech stack decisions, especially in the cloud…

You're absolutely right—tech stack decisions, especially in the cloud and tooling space, reflect deeper philosophies, priorities, and sometimes even personality traits. Let’s unpack everything you’ve asked step by step.

? YouTubers Similar to James Sholtz (CS, Vim-heavy, minimal, etc.)
James Sholtz leans into a clean, efficient, and deep technical approach to programming—especially around Vim, systems, and CS foundations. If you like his style, you’ll probably appreciate:
1. ThePrimeagen
Vim power user, heavy on performance and systems thinking.
Works at Netflix, very opinionated, but hilarious and insightful.
2. Ben Awad
Full-stack dev with strong opinions, occasionally shows off tooling like Vim, Neovim setups, and TypeScript/GraphQL.
3. TJ DeVries
Core Neovim contributor.
Talks deeply about Neovim plugins, Lua, and productivity workflows.
4. Chris@Machine
Focuses heavily on Neovim, dotfiles, Linux tooling.
Very config-heavy videos, appealing if you like building your dev environment like a craftsman.
5. ByteByteGo (Alex Xu)
If you like CS foundations, especially system design at scale, this is a great complement.

? Tech Stack of a "Google Shop" Cloud Engineer (Vim-loving, CS-rooted)
### A "Google Shop" usually means
GCP as primary cloud provider
Heavy use of Bazel, gRPC, Protobuf
Preference for Go, Java, Python
Kubernetes (GKE), Istio
Terraform or Deployment Manager (though Terraform is more common outside Google proper)
Internal tools often mirror Google's philosophies (e.g., monorepos, CI/CD with Cloud Build)
Vim/Neovim, tmux, and Linux-based terminal environments
### Philosophy
Engineering-first, not product-first
Performance and scalability over convenience
Favor declarative, structured systems (gRPC > REST, Bazel > npm scripts)
More SRE-style: observability, traceability, infra-as-code

? Senior Cloud Dev/Engineer — Typical Responsibilities & Stack
### These folks are often
Infrastructure experts (Kubernetes, Terraform, CI/CD)
Code + Infra people (IaC + backends)
Deep in observability (Prometheus, Grafana, etc.)
Working with event-driven architecture (Pub/Sub, Kafka, Cloud Events)
Fluent in at least 1-2 backend languages (Go, Python, Java, Rust)
Common stack for a GCP-oriented senior cloud engineer:
Infra: Terraform, GKE, Cloud Run, Anthos (for hybrid)
CI/CD: Cloud Build, GitHub Actions, ArgoCD
Monitoring: Cloud Monitoring, Prometheus, Grafana, Loki
Security: IAM, Workload Identity Federation, VPC SC
Storage: BigQuery, GCS, Cloud SQL/Spanner

? What Does It Take to Be a VP of Cloud?
Yes, this is a real title—VP of Cloud Engineering, VP of Cloud Infrastructure, or even VP of Platform Engineering.
### Skills and Background
15+ years experience
Proven experience scaling infra for millions/billions of users
Deep knowledge of cloud economics (e.g., how to cut $10M/year from infra bills)
Strong leadership over cross-functional teams (infra, DevOps, SRE, security)
Often started as engineers and scaled up with management
### Focus Areas
Vendor negotiations with GCP, AWS
Governance, compliance (SOC 2, HIPAA, etc.)
Strategic direction: multi-cloud? hybrid? cost vs velocity?
Hiring and shaping company culture around infra

? What Does Choosing GCP Say About Someone's Philosophy?
You're right—it’s rarely "just another cloud provider." Here's what going all-in on GCP might imply:
?
### In contrast
AWS-first shops are often enterprise-heavy, full of legacy, and more "pragmatic"
Azure-first shops are often .NET-centric, enterprise/MSP-driven, with a foot in traditional IT
### GCP folks
Often CS-heavy, modern
Early adopters of containerization
Value ML, data tooling, automation

TL;DR — Your Cloud Stack Reflects You
Vim / Neovim devs tend to build up their tools, not buy them.
GCP users tend to lean toward clean abstractions, powerful data tooling, and prefer structured design over flexibility-at-all-costs (à la AWS).
Senior engineers are expected to master infra, automation, and team coordination.
VPs of Cloud shift into cost, scale, governance, and vision.

Want a visual of what a GCP-centric senior dev’s toolchain looks like (like a diagram)? I can sketch that out.
