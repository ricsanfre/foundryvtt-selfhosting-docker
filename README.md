# Foundry-VTT in docker with Traefik

How to host Foundry VTT from your home network using docker and Traefik as HTTP/HTTPS reverse Proxy.

Docker, as container platform, enables the portability of the software between different hosting environments (bare metal, VM, etc.).

Moreover there is a Foundry VTT docker image maintained by the community that can be used instead of developing our own.
Felddy's docker [image](https://github.com/felddy/foundryvtt-docker) will be used. It is maintained with each new release of Foundry and it has millions of docker pull requets and images supporting different architectures (x86, ARM) are generated.

For securing the access through HTTPS using SSL certificates, Traefik will be used.

Traefik is a Docker-aware reverse proxy with a monitoring dashboard. Traefik also handles setting up your SSL certificates using Let’s Encrypt allowing you to securely serve everything over HTTPS. Docker-aware means that Traefik is able to discover docker containers and using labels assigned to those containers automatically configure the routing and SSL certificates to each service. See Traefik documentation about [docker provider](https://doc.traefik.io/traefik/providers/docker/) 


## Prepare networking

Home router port forwarding and DNS must be configured to make Foundry VTT accessible from Internet.

### Port forwarding

Home router port forwarding must be enabled in order to reach a host in your home network from Internet.
Traffic incoming to ports 80 (HTTP) and 443 (HTTPS) will be redirected to the IP address of the server hosting Foundry VTT.

Enable port forwarding for TCP ports 80/443 to `dnstools` node.

| WAN Port | LAN IP | LAN Port |
|----------|--------|----------|
| 80 | `dnstools_ip` | 80 |
| 443 | `dnstools_ip`| 443 |


### DNS configuration

Using your DNS provider, add the DNS records to be used by the Foundry VTT pointing to the public IP address assigned by your ISP (public IP address of your home network)

In case of ISP is using dynmaic IP public addresses, Dynamic DNS must be configured to keep up to date the DNS records mapped to the assigned public IP addresses. 

#### **Configure Dynamic DNS**

In my home network only a public dysnamic IP is available from my ISP. My DNS provider, 1&1 IONOS supports DynDNS with an open protocol [Domain Connect](https://www.domainconnect.org/).
To configure DynDNS IONOS provide the following [instructions](https://www.ionos.com/help/domains/configuring-your-ip-address/connecting-a-domain-to-a-network-with-a-changing-ip-using-dynamic-dns-linux/).

- Step 1: Install python package

    pip3 install domain-connect-dyndns

- Step 2: Configure domain to be dynamically updated

    domain-connect-dyndns setup --domain ricsanfre.com

- Step 3: Update it

    domain-connect-dyndns update --all

### Enabling Firewall

Enable Ubuntu embedded firewall (ufw), allowing only incoming SSH, HTTP and HTTPS traffic.
  ```
  sudo ufw allow 22
  sudo ufw allow 80
  sudo ufw allow 443
  sudo ufw enable
  ```
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


## Create docker network

Create a couple of docker network to interconnect all docker containers:

```shell
docker network create frontend
docker network create backend
```
Containers accesing to `frontend` network are the only ones that are exposing its ports to the host. Since the host will have internet acces, those exposed services will be accesible from Internet. Traefik container will be the only container to be attached to this network.

Containers accesing to `backend` network are not exposing any port to the server and so they are not accesible directly form internet. All backend containers will be attached to this network.

## Configuring and running Traefik

### Securing access to Docker API

Traefik discovers automatically the configuration to be applied to docker containers, specified in labels. 
For doing that Traefik requires access to the docker socket to get its dynamic configuration. As Traefik official [documentation](https://doc.traefik.io/traefik/providers/docker/#docker-api-access) states, "Accessing the Docker API without any restriction is a security concern: If Traefik is attacked, then the attacker might get access to the underlying host".

There are several mechanisms to secure the access to Docker API, one of them is the use of a docker proxy like the one provided by Tecnativa, [Tecnativa's Docker Socket Proxy](https://github.com/Tecnativa/docker-socket-proxy). Instead of allowing our publicly-facing Traefik container full access to the Docker socket file, we can instead proxy only the API calls we need with Tecnativa’s Docker Socket Proxy project. This ensures Docker’s socket file is never exposed to the public along with all the headaches doing so could cause an unknowing site owner.

Setting up Docker Socket Proxy. In the home directory create initial `docker-compose.yaml` file

```yml
version: "3.8"

services:
  dockerproxy:
    container_name: docker-proxy
    environment:
      CONTAINERS: 1
    image: tecnativa/docker-socket-proxy
    networks:
      - web
    ports:
      - 2375
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock:ro"

networks:
  web:
    external: true

```

### Create folders and basic traefik configuration

- Step create traefik directory within User's home directory

   mkdir  ~/traefik

- Create Traefik configuration file `traefik.yml`

  ```yml
  api:
    dashboard: true
    debug: false

  entryPoints:
    http:
      address: ":80"
    https:
      address: ":443"

  providers:
    docker:
      endpoint: "tcp://docker-proxy:2375"
      watch: true
      exposedbydefault: false

  certificatesResolvers:
    http:
      acme:
        email: admin@ricsanfre.com
        storage: acme.json
        httpChallenge:
          entryPoint: http

  ```
  This configuration file:

  - Enables Traefik dashoard (`api.dashboard`= true)
  - Configure Traefik HTTP and HTTPS default ports as entry points (`entryPoints`)
  - Configure Docker as provider (`providers.docker`). Instead of using docker socket file, it uses as endpoint the Socket Proxy
  - Configure Traefik to automatically generate SSL certificates using Let's Encrypt. ACME protocol is configured to use http challenge.

- Create empty `acme.json` file used to store SSL certificates generated by Traefik.

    touch acme.json
    chmod 600 acme.json

### Configuring basic authentication access to Traefik dashboard
Traefik dashboard will be enabled. By default it does not provide any authentication mechanisms. Traefik HTTP basic authentication mechanims will be used.

In case that the backend does not provide authentication/authorization functionality, Traefik can be configured to provide HTTP authentication mechanism (basic authentication, digest and forward authentication).

Traefik's [Basic Auth Middleware](https://doc.traefik.io/traefik/middlewares/http/basicauth/) for providing basic auth HTTP authentication.

User:hashed-passwords pairs needed by the middleware can be generated with `htpasswd` utility. The command to execute is:

    htpasswd -nb <user> <passwd>

`htpasswd` utility is part of `apache2-utils` package. In order to execute the command it can be installed with the command: `sudo apt install apache2-utils`

As an alternative, docker image can be used and the command to generate the user:hashed-password pairs is:
      
```  
docker run --rm -it --entrypoint /usr/local/apache2/bin/htpasswd httpd:alpine -nb user password
```
For example:
 
  htpasswd -nb admin secretpassword
  admin:$apr1$3bVLXoBF$7rHNxHT2cLZLOr57lHBOv1


### Add Traefik service to docker-compose.yml file


```yml
services:
  traefik:
    depends_on:
      - dockerproxy
    image: traefik:v2.0
    container_name: traefik
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true
    networks:
      - web
    ports:
      - 80:80
      - 443:443
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - ./traefik/traefik.yml:/traefik.yml:ro
      - ./traefik/acme.json:/acme.json
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.traefik.entrypoints=http"
      - "traefik.http.routers.traefik.rule=Host(`monitor.yourdomain.com`)"
      - "traefik.http.middlewares.traefik-auth.basicauth.users=admin:$$apr1$$3bVLXoBF$$7rHNxHT2cLZLOr57lHBOv1"
      - "traefik.http.middlewares.traefik-https-redirect.redirectscheme.scheme=https"
      - "traefik.http.routers.traefik.middlewares=traefik-https-redirect"
      - "traefik.http.routers.traefik-secure.entrypoints=https"
      - "traefik.http.routers.traefik-secure.rule=Host(`monitor.yourdomain.com`)"
      - "traefik.http.routers.traefik-secure.middlewares=traefik-auth"
      - "traefik.http.routers.traefik-secure.tls=true"
      - "traefik.http.routers.traefik-secure.tls.certresolver=http"
      - "traefik.http.routers.traefik-secure.service=api@internal"
```

Where:
  - Replace `monitor.yourdomain.com` in `traefik.http.routers.traefik.rule` `traefik.http.routers.traefik-secure.rule` labels by your domain
  - Replace htpasswd pair generated before in `traefik.http.middlewares.traefik-auth.basicauth.users` label. (NOTE: If te resulting string has any $ you will need to modify them to be $$ - this is because docker-compose uses $ to signify a variable. By adding $$ we still docker-compose that it’s actually a $ in the string and not a variable.) 

This configuration will start Traefik service and enabling its dashboard at `monitor.yourdomain.com`. Enabling HTTPS, generating a TLS  and  redirecting all HTTP traffic to HTTPS.


## Configuring and running Foundry VTT


### Create folders and basic Foundry VTT configuration files

- Step 1 create foundry directory within User's home directory

    mkdir ~/foundry

- Step 2 create data directory where all Foundry VTT and database will be stored
    mkdir ~/foundry/data

- Step 3: Create a container_cache directory where Foundry VTT binaries will be stored

    mkdir ~/foundry/data/container_cache

### Create foundry user

Foundry VTT docker image runs as not privileged user (`foundry`) and container automatically change the owner of the `data` directory (docker bind mount)

The same user should exits in the host, in order to show properly the permisions of the files. Check [Dockerfile](https://raw.githubusercontent.com/felddy/foundryvtt-docker/develop/Dockerfile) to see which is the internal user configured

    sudo groupadd --system -g 421 foundry
    sudo useradd --system --uid 421 --gid foundry foundry



### Create docker secrets file to store Foundry VTT credentials and license key

- Create file `~/foundry/secrets.json`

  ```json
  {
  "foundry_admin_key": "foundry-admin-password",
  "foundry_password": "password",
  "foundry_username": "user",
  "foundry_license_key": "foundry-license-key"
  }
  ```

  This will be used by docker image to automatically download the software, configure admin password and installing the license key.

### Add Foundry VTT to docker compose


```yml
secrets:
  config_json:
    file: ~/foundry/secrets.json

  foundryvtt:
    depends_on:
      - traefik
    container_name: foundryvtt
    image: felddy/foundryvtt:release
    hostname: dndtools
    networks:
      - web
    init: true
    restart: "unless-stopped"
    volumes:
      - type: bind
        source: ~/foundry/data
        target: /data
    environment:
      - CONTAINER_CACHE=/data/container_cache
      - CONTAINER_PATCHES=/data/container_patches
      - CONTAINER_PRESERVE_OWNER=/data/Data/my_assets
      - FOUNDRY_PROXY_SSL=true
    ports:
      - target: 30000
        protocol: tcp
    secrets:
      - source: config_json
        target: config.json
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.foundryvtt.entrypoints=http"
      - "traefik.http.routers.foundryvtt.rule=Host(`foundry.yourdomain.com`)"
      - "traefik.http.middlewares.foundryvtt-https-redirect.redirectscheme.scheme=https"
      - "traefik.http.routers.foundryvtt.middlewares=foundryvtt-https-redirect"
      - "traefik.http.routers.foundryvtt-secure.entrypoints=https"
      - "traefik.http.routers.foundryvtt-secure.rule=Host(`foundry.yourdomain.com`)"
      - "traefik.http.routers.fouundryvtt-secure.tls=true"
      - "traefik.http.routers.foundryvtt-secure.tls.certresolver=http"
      - "traefik.http.routers.foundryvtt-secure.service=foundryvtt"
      - "traefik.http.services.foundryvtt.loadbalancer.server.port=30000"

```

Docker image is started using two environment variables:

- `CONTAINER_CACHE=/data/container_cache`: To use a cache for storing installation files instead of download it every time the container is booted
- `FOUNDRY_PROXY_SSL=true`: to indicate that FoundryVTT is running behind a reverse proxy that uses SSL (Traefik). This allows invitation links and A/V functionality to work as if the Foundry Server had SSL configured directly.

- `CONTAINER_PATCHES=/data/container_patches`: path to list of scripts that docker image executes after instalallation before starting the application.
- `CONTAINER_PRESERVE_OWNER=/data/Data/my_assets`: Avoid changing of permissions of the assets folders


## Optional configuration in case of VM running in VBOX

VTT assets (tokens, tiles, etc) shared from host system (windows server) to guest system (Ubuntu VM), avoiding the copy of GBs of information to the VM.


- Step 1. Add a shared folder to the VM and install Guest Additions.

  - Open VirtualBox

  - Right-click your VM, then click Settings

  - Go to Shared Folders section

  - Add a new shared folder

  - On Add Share prompt, select the Folder Path in your host that you want to be accessible inside your VM. (my_assets_local_folder)

  - In the Folder Name field, type `my_assets`

  - Uncheck Read-only and Auto-mount, and check Make Permanent

  - Start your VM

  - Install VBOX guest additions

    Once your VM is up and running, go to Devices menu -> Insert Guest Additions CD image menu
    Use the following command to mount the CD:

        sudo mount /dev/cdrom /media/cdrom

    Install dependencies for VirtualBox guest additions:

      sudo apt-get update
      sudo apt-get install build-essential linux-headers-`uname -r`

    Execute the installation

      sudo /media/cdrom/./VBoxLinuxAdditions.run

- Step 2: Create mounting target directory
    
     sudo mkdir $HOME/foundry/data/Data/my_assets

- Step 3: Change owner of the target directory to user `foundry`

      sudo chown -R foundry:foundry $HOME/foundry/data/Data/my_assets

- Step 4: Change `/etc/fstab` file to automount the shared directory
    Add the followin line
    
      my_assets /home/user/foundry/data/Data/my_assets vboxsf  rw,uid=421,gid=421  0 0
    
    where
    
    - `my_assets` is the name of the shared folder specified in step 1
    - `rw,uid=421, gid=421` are the mounting options: mounted as readwrite and changing the owner to user id `foundry` and group_id `foundry
    - `vboxsf` is the filesystem type 

- Step 5. Reboot server

- Step 6: check the shared folder is mounted automatically in /home/user/foundry/data/Data/my_assets

