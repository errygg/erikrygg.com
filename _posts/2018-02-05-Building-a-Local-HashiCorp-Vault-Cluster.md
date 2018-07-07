---
layout: post
title: Building a Local HashiCorp Vault Cluster - Volume 1
date: 2018-02-05
categories: [ devops vault ssh security ]
---

![Lock Image](https://cdn-images-1.medium.com/max/2000/1*9Fea6EaEbDtRaZ9vIefzgQ.jpeg)

# Building a Local HashiCorp Vault Cluster - Volume 1
#### Let the infrastructure team figure out the deployment while we build out the policies

> This blog was originally posted [here](https://medium.com/rigged-ops/building-a-local-hashicorp-vault-cluster-5575fe322a17) on Medium

[HashiCorp Vault](https://vault.io) is a sweet little product that can do all sorts of super cool, super secret management, but a production-level deployment is a bit of a task. Depending on how you want to store your secrets and how fault tolerant you want your clusters to be, it could take upwards of 8 or more instances (be it container, virtual machine, etc.). And that will just get you a Vault to work with, then there's a daunting task of building policies, integrating backends, adding audits… my head hurts already.

In order to tackle this problem it makes sense to parallelize a little bit here. Let the infrastructure folks figure out the best way to architect and manage the deployment while we figure out how the heck Vault actually works within our organization. In order to do that easily, we can just spin up a simple local environment and get to work right away on our policy buildout.

## Deploy Dev Server Instance and Setup a Client
Firstly, we are going to deploy a couple Docker containers, so we need to setup a Docker network to get these containers talking to each other. Assuming you already have Docker setup on your dev machine (we're using Docker for Mac) it's as simple as:

```bash
MY-MAC$ docker network create vault-net
<vault-net ID>
```

Alrighty, now we have the network we can use to connect our containers. To get the Vault server instance running, we'll pull down [HashiCorp's Vault](https://hub.docker.com/r/_/vault/) image and run it:

```bash
MY-MAC$ docker pull vault
MY-MAC$ docker run --network vault-net --cap-add=IPC_LOCK -e 'VAULT_DEV_ROOT_TOKEN_ID=my_root_token_id' -p 8200:8200 vault
<Logs and stuff will show up here>
```

Note we are also connecting to the `vault-net` network. In a separate terminal (ensure you have the `vault` binary installed on your local machine) run:

```bash
MY-MAC$ export VAULT_ADDR=http://0.0.0.0:8200
MY-MAC$ export VAULT_TOKEN=my_root_token_id
MY-MAC$ vault status
Seal Type: shamir
Sealed: false
Key Shares: 1
Key Threshold: 1
Unseal Progress: 0
Unseal Nonce:
Version: 0.9.1
Cluster Name: vault-cluster-b631b373
Cluster ID: 2814a88c-4074-9122-3f9d-f5e81d7e8fc1
High-Availability Enabled: false
```

Sweet! We have a `dev` Vault instance running in a container and we can connect to our instance outside the container. Now what?

We're going to build another container that we can use as a Vault client to connect via SSH using a One Time Password (OTP).

## One Time SSH Passwords
Ok, now we are going to setup our vault instance to deal with ssh using an OTP. We use this as a way to manage shared users such as the default `ubuntu` user on our ephemeral instances. This gives us a way to still ssh onto our nodes without propagating all the users to the nodes.

### Server Setup
Firstly, we'll need to mount the backend on our local machine:

```bash
MY-MAC$ vault mount ssh
Successfully mounted 'ssh' at 'ssh'!
```

Now we need a role to provide OTP to the clients. We'll allow the `ubuntu` user on our client node to use this role.

```bash
MY-MAC$ vault write ssh/roles/otp_role key_type=otp  default_user=ubuntu cidr_list=172.18.0.0/16
```

### Client Setup
We'll need a node we can use to ssh to for our test, so let's go ahead and setup a simple docker ssh container (note: this is a container I built specifically for this demo, it's just a sshd container with sshd/PAM configured as well as vault-ssh-helper installed and you can check out the internals [here](https://github.com/errygg/docker-vault-ssh-helper)). First, prune them since we are explicitly naming this container.

```bash
MY-MAC$ docker container prune -f
Total reclaimed space: XB
MY-MAC$ docker run -d -P --name vault_ssh_client --network vault-net errygg/vault-ssh-helper
MY-MAC$ docker port vault_ssh_client
22/tcp -> 0.0.0.0:<random_port>
```

Cool, now we've got a client running attached to our `vault-net` network. But, the container is configured with PAM to connect to Vault and we don't have any local users that are able to authenticate with local passwords. So we'll use the `ubuntu` user to authenticate with the vault service. Docker networking defaults to using the 172.18.0.0/16 subnet, so the vault instance should be 172.18.0.2 and the client should be 172.18.0.3. To get the client to connect to Vault with `ubuntu` set the same env vars we did earlier and ssh to the box from our localhost. First, get the OTP:

```bash
MY-MAC$ vault write ssh/creds/otp_role ip=172.18.0.3
Key             Value
---             -----
lease_id        ssh/creds/otp_role/<ID>
lease_duration  768h0m0s
lease_renewable false
ip              172.18.0.3
key             <Password>
key_type        otp
port            22
username        ubuntu
```

Now try to ssh using the `<Password>`

```bash
MY-MAC$ ssh ubuntu@localhost -p <random port>
Password: <Password>
Welcome to Ubuntu 14.04 LTS (GNU/Linux 4.4.0-101-generic x86_64)
* Documentation:  https://help.ubuntu.com/
The programs included with the Ubuntu system are free software;
the exact distribution terms for each program are described in the
individual files in /usr/share/doc/*/copyright.
Ubuntu comes with ABSOLUTELY NO WARRANTY, to the extent permitted by
applicable law.
ubuntu@a7037c6c8dae:~$
```

Nice! We've got OTP working with `ubuntu` using Vault roles/creds and the
`vault-ssh-helper`! Pretty cool, but even cooler would be using Vault as a
[certificate authority](https://www.vaultproject.io/docs/secrets/ssh/signed-ssh-certificates.html) to store and distribute signed ssh keys for individual
users. Stay tuned, we'll explore that in the next iteration of my Vault journey!

---

Image Credit: [Kristian Hoffer](https://www.freeimages.com/photographer/kikko77-32856)
