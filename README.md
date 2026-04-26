# Nextcloud Azure 

With this **Nextcloud Azure** Repo setting up nextcloud on Azure becomes a no-brainer. It's highly opinionated and sets up nextcloud in a very specific way that depicts a standard nextcloud hosting. The costs for the hosting depend on some variables, such as disk and vm size you choose, but leaving everything at default will give you a fully working nextcloud setup at roughly **35€ max.** per month.

The setup includes: 

- Nextcloud with OIDC extension configured for Entra ID as the Authority (Microsoft Login), email, calendar and password store extensions installed
- Postgres DB (database)
- Redis (caching)
- SWAG (secure proxy) 

## Workflow 1 

Deploys and configures all required Azure Resources for you incl. 

- Resource Group
- VNet 
- NSG
- Service Principal for the VM 
- Managed Identity for the VM
- Static Public IP for the VM
- DNS
- VM
- Managed Disk

## Workflow 2 

Deploys the required Nextcloud components on the VM.

# Prerequisities

Make sure you have: 

- a domain under your control (buy one at [Cloudflare Registrar](https://www.cloudflare.com/products/registrar/) for instance)
- An active Azure Account + Subscription 

# Getting Started

To get started you can just run the workflows manually, no triggers defined at this point.

## Deploy Resources

Run _Workflow 1_ once to deploy the resources from the _cloud-init\nextcloud.bicep_ first. 

### Configuring the Pipeline

tbd

### Running the Pipeline

tbd

## Deploy Nextcloud 

Run _Workflow 2_ once to deploy the `deployment` folder to the vm.

This deploys: 

- Nextcloud with OIDC extension configured for Entra ID as the Authority (Microsoft Login), email, calendar and password store extensions installed
- Postgres DB (database)
- Redis (caching)
- SWAG (secure proxy)

### Configure the Pipeline

tbd

### Run the Pipeline

tbd

# Local Testing

## Prerequisities

Make sure you have git (bash) and docker installed on your machine. 

## Running the test environment

You can test the whole setup locally if you want to know what it will look like once it is up. Run 

```Powershell
.\local-testing\up.local
```

It will generate some certs using git bash and copy a somewhat hackish `nextcloud.subdomain.conf` into your mounted volumes.  It then runs the compose file with some pre-defined secrets and env vars. 

Note that localhost does not support subdomains (no nextcloud.localhost possible) and therefore it will launch nextcloud on `https://localhost:443` instead of `nextcloud.<your-domain>` as it will be on azure. 

# Extending the Setup 

You may want to set your nextcloud up with different extensions. While you could manage them all after the initial setup you can also extend the setup right here in the repo. Just add scripts for the installation of the extensions you desire to `deployment\post-install`. 

Note: Currently scripts run only after the first installation, so no possibility to re-deploy and run additional scripts once in a while. For consecutive installs, use the nextcloud interface. 

# Defaults & Monthly Costs

Azure VM: B2pls (24€)
Managed Disk: E10 Standard SSD WITHOUT snapshots (9€)
Azure DNS: Zone 1 (0.6€)


