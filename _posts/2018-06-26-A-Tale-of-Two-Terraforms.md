---
layout: post
title: A Tale of Two Terraforms - A Model for Managing Immutable and Mutable Infrastructure
date: 2018-06-26
categories: [ devops terraform packer immutable ]
---

![Tale of Two Cities Image](http://assets.signature-reads.com/wp-content/uploads/2018/04/tale-of-two-cities-cover-detail.png)

# A Tale of Two Terraforms — A Model for Managing Immutable and Mutable Infrastructure

> This blog was originally posted [here](https://medium.com/rigged-ops/a-tale-of-two-terraforms-a-model-for-managing-immutable-and-mutable-infrastructure-fa0f5422c27b) on Medium

Look, immutable infrastructure is awesome and if you haven’t looked into this deployment methodology you should really read [this](https://blog.codeship.com/immutable-infrastructure/) article. [Florian Motlik](https://blog.codeship.com/author/florianmotlik/) discusses what immutable really is (FYI, it’s not just containerization) and how to properly role in new changes atomically to minimize, or even eliminate, downtimes due to upgrades, patches, etc.

However, immutable isn’t always an option, in fact most enterprises take time to migrate to new architectures and it is often necessary to keep some mutable servers around until we can properly architect an atomic, blue-green, change process. What I want to propose is a way for you to build up immutable components while also maintaining some of the older mutable, managed instances, all with the help of Terraform and Packer!

## Terraform Your Infrastructure

Ok, hopefully if you are reading this article you’ve at least heard of Terraform. I’m biased because I’m an avid user of Terraform, but it rocks as a solution for codifying your infrastructure and even your applications. If you haven’t played with the open source version, head over here and play with it a bit. It will probably change your life.

Those of you who have played with it may know how to build up some base infrastructure, like a VPC or VNet, add some subnets, routes, NACLs, etc. Once you get the base laid down though, you now have to bring up some instances. It could be a VPN, NAT, bastion host, or an application instance. Lets explore how you would use Terraform to configure a bastion host that you might use as an SSH gateway for users to get into your brand new VPC you built. We won’t go into the instance creation itself as we want to discuss configuring (or provisioning) instances.

### Terraform Provisioning

A nice clean way to provide optional provisioning in your modules is to define a `null_resource` that will run the provisioning if the caller so chooses. Here is an example:

```hcl
resource "random_id" "bastion" {
  byte_length = 8
}
resource “null_resource” “run_chef” {
  # Provision nodes with chef if chef is enabled
  count = “${var.chef_enabled ? var.node_count : 0}”
  provisioner “chef” {
    environment = “${var.environment}”
    version         = “${var.chef_version}”
    server_url      = “${var.chef_server_url}”
    recreate_client = true
    user_name       = “${var.bootstrap_user}”
    user_key        = “${file(var.bootstrap_pem)}”
    # Run list is based off of `name_prefix` AWS tag
    run_list = [“role[${var.environment}]”]
    # Unique node name using random_id resource
    node_name = “bastion-${var.environment}-${element(random_id.bastion.*.hex, count.index)}”
  }
}
```

Ok, the big bit here that we’ve done to make this a _mutable_ instance is that we’ve added a _provisioner_ block. This is fine, but we have pushed the main configuration to the deployment of this instance. Now there are a couple things to note here. Terraform provisioners are only run when the resource is created, not every time that Terraform is run. So, that means you’ll have to manage the continual run of chef using a cron job or run chef as a service. Also, if the provision fails (i.e. cookbook fails) then the terraform run will fail as well. Rerunning terraform will actually just recreate the entire resource again and provision again.

Now this is fine and good, we’re going to let our team start using this bastion while we build up the rest of the infrastructure.

(Months go by and immutable enters the picture)

### Packer Provisioning then Terraform the Infrastructure

Now that we have an operational environment we’ve decided to change it on it’s head and go immutable. We are going to start with immutable VMs. Well, there’s immediately a problem. That bastion host we built up months ago is now a special snowflake that if we make any mods to it, the dev team will cry foul, schedules will push, and basically our heads will be displayed on pikes. So, instead of deal with that, we are going to start rolling out new bastion hosts that folks can migrate to. These are going to be built with Packer and configured well in advance of the deployment. With Packer we will create a _custom_ AMI/VHD/Image for us to use in the deployment. The fundamental difference here is that we’ve moved the provisioning from deployment way back to the left during the development phase. What? There’s a “development phase” for infrastructure? Yes!

If we take what we did in Terraform above and pull it into a Packer JSON template, it would look like:

```hcl
{
  "variables": {
    "environment": "{{env `PACKER_CHEF_ENV`}}",
    "chef_server_url": "{{env `PACKER_CHEF_URL`}}"
    "bootstrap_user": "{{env `PACKER_CHEF_BOOTSTRAP_USER`}}",
    "bootstrap_pem": "{{env `PACKER_CHEF_BOOTSTRAP_PEM`}}"
  },
  "builders": [ ... ],
  "provisioners": [
    {
      "type": "chef-client",
      "chef_environment": "{{ user `environment` }}",
      "server_url": "{{ user `chef_server_url` }}",
      "validation_client_name": "{{ user `bootstrap_user` }}",
      "validation_key_path": "{{ user `bootstrap_pem` }}",
"run_list": [
        "role[{{ user `environment` }}]"
      ],
      "node_name": "bastion-{{ user `environment` }}"
    }
  ]
}
```

Once the new image is built with Packer, we can then just reference the new image ID and forego the provisioning phase all together in our Terraform code. This makes for a much cleaner and easily maintainable infrastructure.

## Mutable and Immutable Living Side-by-Side

Ok, so the above example is best case. I’ll admit it is difficult to migrate from mutable to immutable. That snowflake instance we built months ago may need to live on for quite some time, so we’ll need to manage it via some configuration management tool until we can convince the dev team they need to move to the new immutable bastion. This is going to be the majority of cases when migrating to immutable architecture. It will be a process of going service by service and doing the blue-green deployment: spin up the new immutable stuff, switch a load balancer over, make sure everything is cool, then shut down that old busted mutable cluster.

This migration sounds challenging and hard, but once you’ve done it once the migrations become easier and easier and eventually blue-green deployments will be a breeze. Rolling in new changes is easier, faster, and safer. Infrastructure development can include all sorts of goodies like policy enforcement (these instances need these tags), infrastructure testing, throughput testing, etc. And all this can happen well in advance of deployment which means your infrastructure is now able to accept safe, tested, and resilient change.

Go forth and change my friends!
