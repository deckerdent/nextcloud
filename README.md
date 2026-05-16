# Nextcloud Azure 

With this **Nextcloud Azure** Repo setting up nextcloud on Azure becomes a no-brainer. It's highly opinionated and sets up nextcloud in a very specific way that depicts a standard nextcloud hosting with defaults. The costs for the hosting depend on some variables, such as disk and vm size you choose, but leaving everything at default will give you a fully working nextcloud setup at roughly **40€ max.** per month.

The setup includes: 

- Nextcloud with OIDC extension configured for Entra ID as the Authority (Microsoft Login) extension installed
- Postgres DB (database)
- Redis (caching)
- SWAG (secure proxy) 

## GitHub Actions Workflow 

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

and deploys and configures Nextcloud for you based on only 4 parameters.

# Prerequisities

Make sure you have: 

- a domain under your control (buy one at [Cloudflare Registrar](https://www.cloudflare.com/products/registrar/) for instance)
- An active Azure Account + Subscription 

# Quick Start

Fork this repo into one of yours. Then create an environment for your Github Workflow named "prod" and create the following secrets: 

```
AZURE_CLIENT_ID
AZURE_SUBSCRIPTION_ID
AZURE_TENANT_ID
```
Follow [this guide](https://learn.microsoft.com/en-us/azure/developer/github/connect-from-azure-openid-connect) and finish your environment setup.

Then run the GitHub Actions Workflow _"Deploy Resources"_. 

# Getting Started

[Fork](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/working-with-forks/fork-a-repo) this repository into your own. Alternatively `git clone` the repo and `git remote set-url origin <your-repo-url` manually. 

Make sure you fulfill the the pre-requisits.

## Setting Up The Managed Identity for Your GitHub Action

Follow [this guide](https://learn.microsoft.com/en-us/azure/developer/github/connect-from-azure-openid-connect) to create the managed identity / service principal and create the GitHub Action environment named **prod**. 

Then grant the managed identity or service principal (depending on the option you chose in the guide above) the **Role Based Access Control Administrator** and the **Contributor** privilege. [This guide](https://learn.microsoft.com/en-us/azure/role-based-access-control/role-assignments-portal) explains how to grant a role in general. 

### Running the Pipeline

Navigate to the actions tab of the repo, select **Deploy Resources** and afterwards **Run Workflow**. You'll be prompted to provide 2-4 inputs. At least provide: 

**Domain Name:** Required for your Browser to route to Nextcloud later on. You can provide a full domain or any subdomain of a parent you own. E.g. `example.org` works as much as `cloud.example.org`. Keep in mind, the deployment will install nextcloud to a subfolder of this domain, so you will always have to append `/nextcloud` to address your nextcloud instance, e.g. `cloud.example.org/nextcloud`.

**Email Address:** An email address you own. Can be any, just required for Let's encrypt to notify you in case of problems with your certificate.

The job will run for about 5-15 minutes depending on latency. At the end it will print out the most important parameters of the setup which are: 

**Your assigned Azure DNS Nameservers**: These are the ones your subdomain was registered to and that know about the IP your domain is meant to point to. 

**Public Static IP**: The IP of your virtual machine Nextcloud runs on.

**The Resource Group**: The Azure Resource Group this workflow created.

**The Keyvault**: The keyvault this workflow created.

## Last Steps 

This repo tries to do as much of the heavy lifting for you as possible, but there are two things we cannot do for you reliably. 

**Create NS Entries in your Registrars DNS**: Go to the website of your registrar (where you bought your domain) and create NS Entries for the Azure DNS Nameservers printed in the final step of the workflow.

**Add yourself to the keyvaults secrets users**: This workflow grants **ONLY** the vm access to the keyvaults secrets. If you visit the keyvault, you will see a permission error message in the portal. Grant yourself this permission by assigning yourself the secrets user role for this keyvault **AND** either adding your IP address to the range of allowed IPs or disable Network Protection of the keyvault (not recommended). 

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
Static IP: For internet access (2.3€)

# Known Issues

Currently there are some pending topics. The following list might not be enclosed, but should cover the most important ones: 

- The VNets SSH inbound rule is set to allow all IPs and Ports. This should be handled smarter, but as we don't know the users actual IP (or if they even have a static ip for their PC) it's impossible to narrow it down upfront. We also don't want to force the user of this repo to setup a vpn at this point

- Keyvault could be configured more conveniently with the user given permissions on the secrets out of the box. It's certainly possible to do that without completely screwing security.

- A lot of refactoring is open to make the whole setup a bit more dynamic with choosing different disk or vm sizes, parameterizing usernames... doing this we can also restructure the biceps a bit with more use of variables etc.

- The scripts are a bit messy (and honestly mostly generated) and could encapsulate problems better + less spagetti code, more functions etc.

- The workflow may fail if the users subscription lacks allowance for the particular compute/vm sizes. We could check that before executing the bicep.

- Lasty the workflow has way too much inline bash code. 



