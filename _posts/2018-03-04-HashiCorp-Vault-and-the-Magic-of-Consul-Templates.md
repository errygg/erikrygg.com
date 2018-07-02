---
layout: post
title: HashiCorp Vault and the Magic of Consul Templates
date: 2018-03-04
categories: [ devops terraform vault consul kitchen ]
---

![Gandolf Image](https://cdn-images-1.medium.com/max/1600/1*MFI0A3dkVjixTwdYZLqEDw.jpeg)

# HashiCorp Vault and the Magic of Consul Templates
#### Using Terraform to Spin up Vault/Consul and Pull Secrets with consul-template

> This blog was originally posted [here](https://medium.com/rigged-ops/hashicorp-vault-and-the-magic-of-consul-templates-d4a053e7a4cc) on Medium

Ok, so I know I said I’d talk more about how to sign ssh keys using the Vault CA, but I got side tracked with how awesome Consul is and how to integrate it with Vault. I also wanted to build a _real_ Vault instance with a _real_ Consul backend and didn’t want to do it in AWS because I’m cheap (and on a plane often). So I built up a production-worthy stack locally with Docker on my Mac and it works like a champ! So stoked to show you how it works, but it did get a little involved.

The basic architecture is relatively simple. I spun up 3 Docker containers — a vault server, a consul backend server, and a vault/consul-template client. As much as I’d like to say it was a simple task, it got a bit complicated. Not to mention I also decided to throw in Terraform to codify the build but also kitchen-terraform to test it all out. Phew! That’s a lot of HashiCorp tech all wrapped into a nice little package.

To start out, here are the technologies utilized in this example:

* [kitchen-terraform](https://newcontext-oss.github.io/kitchen-terraform/tutorials/docker_provider.html)
* [Terraform](https://www.terraform.io/docs/providers/docker/index.html)
* [Docker for Mac](https://www.docker.com/docker-mac)
* [Vault](https://www.vaultproject.io/docs/index.html)
* [Consul](https://www.consul.io/docs/index.html)
* [consul-template](https://github.com/hashicorp/consul-template#consul-template)

If you haven’t used kitchen-terraform before, you’re in for a treat. It’s a sweet tool that allows you to build test suites for your Terraform modules and use Inspec to validate your deployments. We won’t be doing the Inspec validation in this blog, but kitchen-terraform allows us an easy way to test out a live configuration with the (relatively) generic modules.

Another item to note here is that Vault really isn’t meant to be completely automated. There are some security decisions made in the design that make it difficult, if not impossible, to completely automate the deployment AND configuration. Specifically, where I found the biggest hurdle here was with authenticating the consul-template client. AFAIK, the only way to authenticate the consul-template client is to use a non-root token, and automating a user token became very difficult. Mitchell Hashimoto himself discussed in this Github issue the security implications of doing so. So, with that, we do have a couple manual bits and pieces we’ll run to get this stack up and running in a (relatively — non-TLS, but that’s the only bit I skimped on) production-ready deployment.

## Here We Go!
This is the GitHub project I built to accomplish all this awesomeness, so you can play along!

### Step 1 — Setup the Initial Stack

In that project, navigate to `vault-integration-exmamples/consul-template/modules/setup_stack`.

Run `bundle exec kitchen converge`. This will run test-kitchen with the kitchen-terraform driver. You’ll see lots of stuff happening so let’s break it down.

kitchen-terraform is a test driver for testing out Terraform code. This project is constructed using Terraform to build up the vault, consul, and client (with consul-template). We use Docker networking to network all these containers together. The Vault and Consul Docker containers are just using the Docker Hub images available from HashiCorp. The client container is built up using a base ssh container. In the Terraform code, I use a combination of berkshelf and chef-zero as well as some good ol’ scripting to install consul-template, the Vault and Consul binaries, and the associated configuration.

_There’s a bit of work-around-ary in my repo and if you want to get the reasons why, please send me a note._

The outputs include the internal Docker network IP addresses and hostnames for the containers.

Now, because of the way the root token is created and output with Vault, it’s output into a file in `vault-integration-examples/consul-template/modules/setup_stack/tmp/vault_root_token.txt`.

### Step 2 — Store the Vault Root Token

Terraform allows you to store information in environment variables and use them in your modules. So, we’ll do that here with the root token. Run the following on your localhost:

```bash
export TF_VAR_root_token=<root_token>
export VAULT_ADDR=https://localhost:8200
```

### Step 3 — Configure the Client

Now we’ll configure Vault with the Vault Terraform provider. The Vault container exports the service port to the localhost, so we’ll be able to configure the Vault policies and backends locally. Now you can just run `bundle exec kitchen converge in vault-integration-examples/consul-template/modules/config_stack`.

Unfortunately, we’re done with the Terraform work now. It’s all manual from here.

### Step 4 — Get the User Token

Now the user has been configured in Vault using the userpass backend, we’ll login (we can run this locally) with that username/password and get the token:

```bash
vault login -method=userpass username=myusername
```

Use `mypassword` as the password and save off the token.

### Step 5 — SSH into the Client and Run consul-template

Now let’s start working with the client so we can actually show how consul-template will work.

ssh now into the client:

```bash
ssh root@localhost -p 2222
```

and use `root` as the password. Take a look at the consul-template we’ll be using. The file is in /root/sectets.txt.tpl. This is a simple consul-template file where `.Data.myvalue` will be replace by the secret we have mapped in Vault. consul-template will not allow you to use root tokens to render files, so this is why we’ve setup a username/password without root policies. Lets export the user token so we can login to Vault with a user token:

```bash
export VAULT_TOKEN=<user_token>
```

We already have consul-template configured, so we can simply run:

```bash
consul-template -once -config=/root/consul_template_config.json
```

We are running `-once` so we don’t run consul-template as a daemon.

### Step 6 — Check out the consul-template File

Take a look at `/root/secrets.txt` and you should see `mysecret` actually put into the file where `.Data.myvalue` was in the .tpl file! Nice job, you did it. There’s a ton of stuff you can do with Consul templates, but this is just an example of how to do it with a production-level Vault/Consul setup.

Stay tuned for the next iteration of my Vault journey!
