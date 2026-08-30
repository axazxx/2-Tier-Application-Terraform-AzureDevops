# OVERVIEW
- This project establishes a production-ready infrastructure on Microsoft Azure by deploying a two-tier architecture across Availability Zone 1 and
  Availability Zone 2 in the East US region which showcases its capability as a High Availability architecture.
- The entire infrastructure lifecycle is fully automated via Infrastructure as Code using Terraform,leveraging an Azure Blob remote state backend and a declarative
  two-stage Azure DevOps YAML pipeline running on a self-hosted Linux agent to validate, plan, artifact, and auto-provision resources consistently across local
  and CI/CD environments.
- Incoming user traffic is evenly distributed across multiple Nginx web instances via an Azure Standard Load Balancer with active health checkups.
- The architecture consists of Two tiers; Web & Db. Both have nsg's attached restricting everyone inbound to Db except Web. This portrays good security.

# TO RUN LOCALLY:-
#Prerequisites
-Terraform CLI (v1.5+)
-Azure CLI (az)
-SSH Key pair generated on your machine (~/.ssh/id_rsa.pub)

#Step-by-Step Execution
- Clone the repository: ~ git clone https://github.com/axazxx/2-Tier-Application-Terraform-AzureDevops.git
- ~ cd 2-Tier-Application-Terraform-AzureDevops
- Authenticate with Azure: ~ az login
- Initialize Terraform & Remote Backend: ~ terraform init -reconfigure
- Review Plan & Deploy: ~ terraform plan
- ~ terraform apply -auto-approve
- See the Deployment:
- Open the Load Balancer IP you got in your browser
  ~ http://<load_balancer_ip>
  or
- ~ curl http://<load_balancer_ip>

# TO RUN ON AZURE DEVOPS
- create a self-hosted-agent named pool and create an linux agent on top of an azure linux vm. Follow these steps:-
- Step 1: Generate a Personal Access Token (PAT) in Azure DevOps;
1.In the top right corner on Azure Devops, click your profile icon and select User settings ➔ Personal access tokens.
2.Click + New Token.
3.Configure the token details:
Name: vmagent-pat
Organization: Select your organization.
Scopes: Select Custom defined ➔ under Agent Pools, check Read & manage.
4.Click Create and copy the generated token immediately.

- Step 2: Create or Select the Agent Pool
1.Go to Organization Settings (or Project Settings). Under Pipelines, click Agent pools.
2.Select an existing pool (self-hosted-agent) or click Add pool to create a new one.

- Step 3: Connect to the Linux VM and Download the Agent
1.SSH into your target Linux VM from your local terminal:

Bash
~ ssh -i /path/to/your-key.pem azureuser@<VM-Public-IP>
2.Inside the VM, create the agent folder and download the agent package:
Bash
mkdir -p ~/myagent && cd ~/myagent

3.Download the latest Linux x64 agent package
curl -O https://vstsagentpackage.azureedge.net/agent/3.248.0/vsts-agent-linux-x64-3.248.0.tar.gz

4.Extract the archive
tar -zxvf vsts-agent-linux-x64-*.tar.gz

- Step 4: Install System Dependencies

Bash
~ sudo ./bin/installdependencies.sh

- Step 5: Configure the Agent

Bash
./config.sh

Enter the required details when prompted:

Server URL: [https://dev.azure.com/](https://dev.azure.com/)<your-organization-name>
Authentication type: Press Enter (defaults to PAT)
Personal access token: Paste your PAT generated in Step 1
Agent pool: Enter the pool name (e.g., self-hosted-agent or Default)
Agent name: Enter a name for the agent (e.g., vmagent)
Work folder: Press Enter (defaults to _work)

- Step 6: Install Required Build Tools (Azure CLI & Terraform)

Bash
#Install Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

#Install Terraform
sudo apt-get update && sudo apt-get install -y gnupg software-properties-common curl
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt-get update && sudo apt-get install -y terraform

- Step 7: Run the Agent as a Systemd Background Service
Bash
cd ~/myagent
sudo ./svc.sh install
sudo ./svc.sh start
sudo ./svc.sh status
Navigate back to Project Settings ➔ Agent pools ➔ [Your-Pool] ➔ Agents in Azure DevOps to confirm the agent status is Online.
- 
- import repos from github in azure repos
- go to azure pipelines and create a new pipeline for the project and run the pipeline
- final ouput will be an IP address which you can use in a browser to check if its deployed.
