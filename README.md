# 🏗 Architecture Overview

```text
+----------------------------------------------------------------------------------------------------+
|                                    AZURE REGION: East US                                           |
|  Resource Group: 2-tier-group-eastus                                                               |
|                                                                                                    |
|                             +-----------------------------------+                                  |
|                             |      Internet / Web Users         |                                  |
|                             +-----------------+-----------------+                                  |
|                                               |                                                    |
|                                               v                                                    |
|                             +-----------------------------------+                                  |
|                             |   Public IP (web_public_ip)       |                                  |
|                             +-----------------+-----------------+                                  |
|                                               |                                                    |
|                                               v                                                    |
|                             +-----------------------------------+                                  |
|                             |   Azure Standard Load Balancer    |                                  |
|                             |   - Frontend: web_frontend        |                                  |
|                             |   - Rule: Port 80 -> Backend Pool |                                  |
|                             |   - Health Probe: HTTP Port 80    |                                  |
|                             +-----------------+-----------------+                                  |
|                                               |                                                    |
|  Virtual Network: myVnet (10.0.0.0/16)        |                                                    |
|  +--------------------------------------------|-------------------------------------------------+  |
|  |  Tier 1: Web Subnet (10.0.1.0/24)          |                                                 |  |
|  |  NSG: web_nsg (Allow HTTP: 80, Allow SSH: 22)                                                |  |
|  |                                            |                                                 |  |
|  |             +------------------------------+------------------------------+                  |  |
|  |             |                                                             |                  |  |
|  |             v                                                             v                  |  |
|  |    +-----------------------------+                               +------------------------+  |  |
|  |    |     Availability Zone 1     |                               |   Availability Zone 2  |  |  |
|  |    |                             |                               |                        |  |  |
|  |    |  +-----------------------+  |                               |  +------------------+  |  |  |
|  |    |  | web_vm-1 (Ubuntu 22)  |  |                               |  | web_vm-2 (Ubuntu)|  |  |  |
|  |    |  | - Standard_B1s        |  |                               |  | - Standard_B1s   |  |  |  |
|  |    |  | - Nginx Web Server    |  |                               |  | - Nginx Server   |  |  |  |
|  |    |  +-----------+-----------+  |                               |  +--------+---------+  |  |  |
|  |    |              |              |                               |           |            |  |  |
|  |    |  +-----------+-----------+  |                               |  +--------+---------+  |  |  |
|  |    |  | web_vm_nic-1          |  |                               |  | web_vm_nic-2     |  |  |  |
|  |    |  +-----------+-----------+  |                               |  +--------+---------+  |  |  |
|  |    +--------------|--------------+                               +-----------|------------+  |  |
|  |                   |                                                          |               |  |
|  |                   | [SSH Port 22]                                            | [SSH Port 22] |  |
|  |                   v                                                          v               |  |
|  |        +--------------------+                                     +--------------------+     |  |
|  |        | web_vm_public_ip-1 |                                     | web_vm_public_ip-2 |     |  |
|  |        | (Admin SSH Only)   |                                     | (Admin SSH Only)   |     |  |
|  |        +--------------------+                                     +--------------------+     |  |
|  +-------------------|----------------------------------------------------------|---------------+  |
|                      |                                                          |                  |
|                      | (Allowed: Port 3306 MySQL)                               |                  |
|                      +----------------------------+-----------------------------+                  |
|                                                   |                                                |
|  +------------------------------------------------v---------------------------------------------+  |
|  |  Tier 2: DB Subnet (10.0.2.0/24)                                                             |  |
|  |  NSG: db_nsg                                                                                 |  |
|  |  - Inbound Rule: Allow Port 3306 from 10.0.1.0/24 (Web Subnet Only)                          |  |
|  |  - Inbound Rule: Deny All Traffic from Internet                                              |  |
|  |                                                                                              |  |
|  |  [Reserved Private Database Tier / Subnet for MySQL / Managed DB Services]                   |  |
|  +----------------------------------------------------------------------------------------------+  |
+----------------------------------------------------------------------------------------------------+
```
(AI Generated Flowchart)


## OVERVIEW
- This project establishes a production-ready infrastructure on Microsoft Azure by deploying a two-tier architecture across Availability Zone 1 and
  Availability Zone 2 in the East US region which showcases its capability as a **High Availability** architecture.
- The entire infrastructure lifecycle is fully automated via Infrastructure as Code using Terraform,leveraging an Azure Blob remote state backend and a declarative
  two-stage Azure DevOps YAML pipeline running on a self-hosted Linux agent to validate, plan, artifact, and auto-provision resources consistently across local
  and CI/CD environments.
- Incoming user traffic is evenly distributed across the two Nginx web instances via an Azure Standard Load Balancer with active health checkups.
- The architecture consists of Two tiers; Web & Db. Both have nsg's attached restricting everyone inbound to Db except Web. This portrays **Strong security**.
- The State file is stored in a container in Storage account on Azure. This also showcases **Strong security** & how we can secure State file which may contain secrets, keys, private IPs

## TO RUN LOCALLY:-
### Prerequisites
- Terraform CLI (v1.5+)
- Azure CLI (az)
- SSH Key pair generated on your machine (~/.ssh/id_rsa.pub)

### Step-by-Step Execution
1. Clone the repository:

   `git clone https://github.com/axazxx/2-Tier-Application-Terraform-AzureDevops.git`

   `cd 2-Tier-Application-Terraform-AzureDevops`

2. Authenticate with Azure:
   syntax: `az login`

3. Create a resource Group:
   syntax: `az group create -n 2-tier-group-eastus -l eastus`
  
4. Create a storage account & a container in it named tfstate:
- Storage Account syntax:
  ```az storage account create \
  --name "anasstorageaccount" \
  --resource-group "2-tier-group-eastus" \
  --location "eastus" \
  --sku "Standard_LRS" \
  --encryption-services blob```

- Container syntax:
  ```az storage container create \
  --name "tfstate" \
  --account-name "anasstorageaccount" \
  --auth-mode login```
  
5. Initialize Terraform & Remote Backend:
   `terraform init -reconfigure`

6. Review Plan & Deploy:
   `terraform plan`
   `terraform apply -auto-approve`

7. Check the Deployment:
   Open the Load Balancer IP you got and paste it in your browser
  `http://<load_balancer_ip>`
  or
  `curl http://<load_balancer_ip>`

## TO RUN ON AZURE DEVOPS
Create a self-hosted-agent named pool and create an linux agent on top of an azure linux vm. 

### Follow these steps:-

**Step 1:** Generate a Personal Access Token (PAT) in Azure DevOps;
1. In the top right corner on Azure Devops, click your profile icon and select User settings ➔ Personal access tokens.
2. Click + New Token.
3. Configure the token details:
Name: vmagent-pat
Organization: Select your organization.
Scopes: Select Custom defined ➔ under Agent Pools, check Read & manage.
4. Click Create and copy the generated token immediately.

**Step 2:** Create or Select the Agent Pool
1. Go to Organization Settings (or Project Settings). Under Pipelines, click Agent pools.
2. Select an existing pool (self-hosted-agent) or click Add pool to create a new one.

**Step 3:** Connect to the Linux VM and Download the Agent
1. SSH into your target Linux VM from your local terminal:

syntax: `ssh -i /path/to/your-key.pem azureuser@<VM-Public-IP>`

2. Inside the VM, create the agent folder and download the agent package:
   
syntax: `mkdir -p ~/myagent && cd ~/myagent`

3. Download the latest Linux x64 agent package:

syntax: `curl -O https://vstsagentpackage.azureedge.net/agent/3.248.0/vsts-agent-linux-x64-3.248.0.tar.gz`

4. Extract the archive:

syntax: `tar -zxvf vsts-agent-linux-x64-*.tar.gz`

**Step 4:** Install System Dependencies:

syntax: `sudo ./bin/installdependencies.sh`

**Step 5:** Configure the Agent:

syntax: `./config.sh`


- Enter the required details when prompted:

Server URL: [https://dev.azure.com/](https://dev.azure.com/)<your-organization-name>

Authentication type: Press Enter (defaults to PAT)

Personal access token: Paste your PAT generated in Step 1

Agent pool: Enter the pool name (e.g., self-hosted-agent or Default)

Agent name: Enter a name for the agent (e.g., vmagent)

Work folder: Press Enter (defaults to _work)

**Step 6:** Install Required Build Tools (Azure CLI & Terraform)

Install Azure CLI syntax:

`curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash`

Install Terraform syntax:

```sudo apt-get update && sudo apt-get install -y gnupg software-properties-common curl
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee/etc/apt/sources.list.d/hashicorp.list
sudo apt-get update && sudo apt-get install -y terraform```

**Step 7:** Run the Agent as a Systemd Background Service

```cd ~/myagent
sudo ./svc.sh install
sudo ./svc.sh start
sudo ./svc.sh status```

- Navigate back to Project Settings ➔ Agent pools ➔ [Your-Pool] ➔ Agents in Azure DevOps to confirm the agent status is Online.

- import repos from github in azure repos
- go to azure pipelines and create a new pipeline for the project and run the pipeline
- final ouput will be an IP address which you can use in a browser to check if its deployed.
