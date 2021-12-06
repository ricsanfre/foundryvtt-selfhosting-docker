# Foundry-VTT in docker with Traefik

How to host Foundry VTT from your home network using docker and Traefik as HTTP/HTTPS reverse Proxy.

Docker, as container platform, enables the portability of the software between different hosting environments (bare metal, VM, etc.).

Moreover there is a Foundry VTT docker image maintained by the community that can be used instead of developing our own.
Felddy's docker [image](https://github.com/felddy/foundryvtt-docker) will be used. It is maintained with each new release of Foundry and it has millions of docker pull requets and images supporting different architectures (x86, ARM) are generated.

For securing the access through HTTPS using SSL certificates, Traefik will be used.

Traefik is a Docker-aware reverse proxy with a monitoring dashboard. Traefik also handles setting up your SSL certificates using Let’s Encrypt allowing you to securely serve everything over HTTPS. Docker-aware means that Traefik is able to discover docker containers and using labels assigned to those containers automatically configure the routing and SSL certificates to each service. See Traefik documentation about [docker provider](https://doc.traefik.io/traefik/providers/docker/) 

## Prepare host

A VM or a baremetal server can be used for hosting the Foundry VTT software. In my case I will be use a Single Board Computer (SBC), a Raspberry PI 4 B.

Ubuntu 20.04 64 bits can be used as OS, and a cloud image and `cloud-init` can be used to automate the instalallation of basic software (docker and docker-compose).

- Step 1 - Create SSH keys

  Authentication using SSH keys will be the only mechanism available to login to the server.
  We will create SSH keys for two different users:

  For generating SSH private/public key in Windows, Putty Key Generator can be used:

    ![ubuntu-SSH-key-generation](images/ubuntu-user-SSH-key-generation.png "SSH Key Generation")


- Step 2 - Prepare cloud-init installation files (`user-data` and `network-config` 

    Change user account details accordingly (in my case: user name is ricsanfre) and add the public SSH key (`ssh_authorized_keys`) by the one generated in step 1.

**`user-data`**

```yml
#cloud-config

# Set TimeZone and Locale
timezone: Europe/Madrid
locale: es_ES.UTF-8

# Hostname
hostname: dndtools

manage_etc_hosts: localhost

## Add docker apt repository
## GPG keys need to be added
## Docker: curl -sL https://download.docker.com/linux/ubuntu/gpg | gpg
## Hashicorp: curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg
apt:
  sources:
    docker.list:
      source: deb [arch=amd64] https://download.docker.com/linux/ubuntu $RELEASE stable
      keyid: 9DC858229FC7DD38854AE2D88D81803C0EBFCD88

# Update packge cache

package_update: true
# Install docker and python packages
packages:
  - apt-transport-https
  - ca-certificates
  - curl
  - gnupg
  - lsb-release
  - git
  - software-properties-common
  - docker-ce
  - docker-ce-cli
  - containerd.io
  - build-essential
  - python3-dev
  - python3-pip
  - python3-setuptools
  - python3-yaml
  - bridge-utils

# Enable ipv4 forwarding
write_files:
  - path: /etc/sysctl.d/enabled_ipv4_forwarding.conf
    content: |
      net.ipv4.conf.all.forwarding=1

# create the docker and libvirt group
groups:
  - docker

# Users. Remove default (ubuntu)
users:
  - name: ricsanfre
    gecos: Ricardo Sanchez
    primary_group: users
    groups: [docker, adm, admin]
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    lock_passwd: true
    ssh_authorized_keys:
      - ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAQEAusTXKfFoy6p3G4QAHvqoBK+9Vn2+cx2G5AY89WmjMikmeTG9KUseOCIAx22BCrFTNryMZ0oLx4u3M+Ibm1nX76R3Gs4b+gBsgf0TFENzztST++n9/bHYWeMVXddeV9RFbvPnQZv/TfLfPUejIMjFt26JCfhZdw3Ukpx9FKYhFDxr2jG9hXzCY9Ja2IkVwHuBcO4gvWV5xtI1nS/LvMw44Okmlpqos/ETjkd12PLCxZU6GQDslUgGZGuWsvOKbf51sR+cvBppEAG3ujIDySZkVhXqH1SSaGQbxF0pO6N5d4PWus0xsafy5z1AJdTeXZdBXPVvUSNVOUw8lbL+RTWI2Q== ubuntu@mi_pc
# Install Docker compose
runcmd:
  - sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  - sudo chmod +x /usr/local/bin/docker-compose

```

**`network-config`**

Modify the IP address, gateway and DNS servers accordingly to the ones used in your home network.

```yml
version: 2
ethernets:
  eth0:
    dhcp4: no
    addresses: [192.168.1.10/24]
    gateway4: 192.168.1.1
    nameservers:
      addresses: [1.1.1.1,8.8.8.8]

```

- Step 3. When burning OS image add `user-data` and `network-config` files before the first booting.

  In case of creating a VM in Virtual Box, the automation script in Windows of this [repo](https://github.com/ricsanfre/ubuntu-cloud-vbox) can be used. 








