---
title: That’s an awesome way to learn ? — running Arch Linux forces you…
date: 2025-08-20
source-folder: Notes
tags: []
---

# That’s an awesome way to learn ? — running Arch Linux forces you…

That’s an awesome way to learn ? — running Arch Linux forces you to really know what’s going on under the hood, which is exactly the mindset you need as a cloud/devops engineer. Since you’ve got the base system running, we can structure a weekly curriculum where you build both Linux fundamentals and cloud/devops skills step by step.
I’ll lay this out like a practical study/exercise plan, not just theory.

? Weekly Curriculum for Aspiring Cloud Developer (Arch Linux Focus)

? Week 1: Linux Fundamentals (your Arch install is the playground)
Goals: Comfort with shell, processes, services, package management, networking.
Exercises
Shell basics
Write 10 one-liner commands to manipulate text files (grep, awk, sed, cut, sort, uniq).
Create a Bash script that renames files in bulk.
Processes
Practice ps, top, htop, kill, systemctl status.
Users & Permissions
Add a new user, assign groups, change permissions (chmod, chown, umask).
Networking
Use ip, ss, ping, traceroute.
Write a script that pings google.com every 10s and logs to a file.
Package management
Install software with pacman and yay.
Build one AUR package from source.

? Week 2: Git, Scripting & Automation
Goals: Version control + automating routine tasks.
Exercises
Git
Create a repo, make commits, push to GitHub/GitLab.
Branch & merge, resolve a conflict.
Scripting
Write a script that backs up /etc daily into a tar.gz.
Automate Arch updates with a script (pacman -Syu, log output).
Write a script that emails you if disk usage > 80% (use df -h + mail or log for now).
Cron
Schedule your backup script with crontab -e.

? Week 3: System Services & Networking
Goals: Deep dive into systemd, services, logging, and networking.
Exercises
Systemd
Write a custom systemd service that runs your ping script at boot.
Enable, disable, restart, check logs with journalctl.
Logging
Redirect logs to /var/log/myapp.log and rotate them.
Networking
Set up SSH server (pacman -S openssh), connect from another device.
Harden SSH (disable root login, use keys).
Use nc (netcat) to open a simple TCP listener and send messages.

? Week 4: Virtualization & Containers
Goals: Get hands-on with Docker (cloud entry point).
Exercises
Install Docker (pacman -S docker), enable it.
### Run
docker run hello-world
docker run -it archlinux bash

Build your first Dockerfile (simple Python “hello world”).
Run PostgreSQL container and connect with psql.
Exercise: Write a Bash script that spins up a container, runs a job, cleans up.

? Week 5: Infrastructure as Code (IaC)
Goals: Learn automation tools used in the cloud.
Exercises
### Install Ansible
pacman -S ansible

Write a playbook that installs nginx on localhost.
Use Ansible to create a user and deploy a config file.
Stretch: Provision multiple containers with Ansible.

? Week 6: Cloud & CI/CD Basics
Goals: Tie Linux + automation into real-world cloud tools.
Exercises
Sign up for a free-tier cloud (AWS, GCP, or Azure).
Launch a VM ? SSH into it (you’ll recognize the Linux environment instantly ?).
Write a script that deploys an app to that VM.
### Explore GitHub Actions
Make a workflow that lints a Python file on push.

? Ongoing Daily / Weekly Habits
### Daily
30 min shell practice (grep, sed, awk drills).
Write 1 small Bash script to solve a problem.
Read Arch Wiki article on something you used that day.
### Weekly Projects
End of each week, pick a “mini-project” (ex: set up nginx as a reverse proxy, create a Dockerized Flask app, deploy to cloud).
### Stretch Goals (Month 2+)
Kubernetes (k3s/minikube).
Terraform for cloud infra.
CI/CD pipelines.

? By following this, in ~6–8 weeks you’ll be comfortable with Linux and applying those skills directly to DevOps/cloud workflows.
? Do you want me to turn this into a structured 6-week roadmap document (like a checklist you can follow and tick off exercises), or keep it conversational and flexible?
