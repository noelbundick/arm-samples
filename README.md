# Azure Resource Manager Template Samples

A brief overview of ARM templates, and a few samples of increasing complexity

## Prerequisites

* [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
* [Azure subscription](https://azure.microsoft.com/en-us/free/)

### Recommended

* [Visual Studio Code](https://code.visualstudio.com/)
* [Azure Resource Manager Tools Extension](https://marketplace.visualstudio.com/items?itemName=msazurermtools.azurerm-vscode-tools)

## 0. Structure

Labeling this `0` because this doesn't actually do anything. But it shows the basic skeleton of a template, and it's worth knowing how to actually deploy a template. Look in the source folders and you'll see a `template.json` and a `parameters.json`, which are exactly what they sound like - an ARM template, and a set of parameters.

### Sections

Unfortunately, JSON doesn't allow comments, so I'll break down the interesting sections here

* Parameters: parameters can be passed into the template (names, instance counts, ports, etc). These can be given defaults and can be overridden multiple times (last one wins)
* Variables: variables can be used to help build your template. A common usage is to generate a unique string based on an input parameter.
* Resources: these are the things that will actually be created - things like VMs, SQL databases, Load Balancers, etc
* Outputs: outputs give you the ability to capture runtime values - such as the value of a dynamically allocated public IP

### How to Deploy

You can deploy and ARM template with the Azure CLI, PowerShell, a VSTS CI/CD workflow, or pretty much whatever you want - bash script, Ruby, C#, etc. The general idea is that you submit a deployment declaring what you want the final state to be, and then ARM will pass calls to the appropriate services to actually create resources.

I'm using the Azure CLI

```bash
# Create a resource group to deploy to
az group create -n trash1 -l southcentralus

# When I'm done playing around, I'll remove everything via:
#az group delete -n trash1 -y --no-wait

# Deploy the template and pass in parameters
# Note "@parameters.json" is not a typo, it tells the CLI to use the contents of the file rather than the string "parameters.json"
az group deployment create -g trash1 --template-file template.json --parameters @parameters.json
```

### Learn More

* [Structure and Syntax](https://docs.microsoft.com/en-us/azure/azure-resource-manager/resource-group-authoring-templates)

## 1. A Storage Account

Going to start off very simple here. Storage Accounts are used as a building block for a ton of services and they have no dependencies.

### Parameters

I've specified namePrefix as a parameter. There's no default value, so it's required to use this template

### Variables

This looked pretty ugly to me at first glance, so I'll break it down to explain. ARM templates have a ton of functions for you to use - this is a pretty typical usage

```json
"storageAccountName": "concat(parameters('namePrefix'), uniqueString(resourceGroup().id))]"
```

The variable is named `storageAccountName`, and has a crazy value

```
[concat(parameters('namePrefix'), uniqueString(resourceGroup().id))]
```

These brackets are the signal to ARM that I'm using a function and this needs to be evaluated. 

* `concat` is a function to concatenate strings
* `parameters('namePrefix')` references the `namePrefix` template parameter
* `uniqueString( ... )` generates a deterministic unique string based on the parameters
* `resourceGroup().id` gets the current Resource Group, and returns the `id` property
  > This means that you'll get a different storage account name when you deploy this to another resource group, which is nice because you won't have to update anything! It can feel like magic, but there's a method to the madness

### Learn more

* [Create Your First Azure Resource Manager Template](https://docs.microsoft.com/en-us/azure/azure-resource-manager/resource-manager-create-first-template) - I found this after creating this repo, and it's nearly identical to this first step, with some additional explanation. Worth checking out

## 2. A Virtual Machine

Virtual Machines are the building block of the IaaS world, and VM's in Azure have quite a bit going on - it's not just a compute resource. Here are some common things I've put together to get a single VM up and running:

* Storage - Whether I use Managed Disks or juggle my own storage accounts, my OS and data disks have to go somewhere
* Virtual Network - I don't want a VM with no connectivity, so I need a VNET with a configured subnet to make it accessible
* Public IP address - I want to host some apps on my VM - so I'm going to snag an IP address with an easy to remember name
* Network interface - Well, I guess that makes sense, I'll associate my network interface with the public IP and put it on my subnet
* Virtual machine - Finally! I'm configuring admin credentials, chosen the OS to install, added some diagnostics config, etc.

Work through this file and make sure you understand what's going on. Clone this, change things, and see what happens. Worst case, you blow up a throwaway resource group, you create a "trash2", and you do it again. I do this all the time - trying out deployments is something I do all the time. Remember, Azure bills you based on usage - you're likely spending only pennies

### Parameters

Notice parameters can have different types - `securestring` won't be visible in the output or logs when I go back and look at the deployment. I've also got a default value for my Ubuntu version.

### Variables

I've created a lot of variables as static strings. This lets me reuse values rather than hardcoding the same value in multiple places. It also lets me quickly make updates later on without having to hunt & peck through the entire file. If I want to derive from a parameter (or another variable), that's a 1-line change. Easy

### Resources

Each resource type has its own set of properties and rules over what values are allowed, which ones are required, etc. Steal from the quickstart samples, download from the Azure Portal, and/or read the REST API docs.

ARM has the ability to honor dependencies and deploy things in the correct order. It can infer the ordering through use of the `reference(...)` function, or you can set the order explicitly in the `dependsOn` property of a resource.

### Outputs

So I've got this public IP, but I don't know what it is until Azure provisions me one. And I don't want to go look it up later. Outputs to the rescue! I'm outputting the FQDN of my IP (and therefore VM), and a command to SSH into the box using my custom admin account and the correct address.

> Note: You can use runtime values in the outputs section, but not in the variables section

## 3. VM Scale Sets

One VM is cool, but the cloud is all about elastic scale! I want to scale my static website to 100's of cores.

### Deployment

You'll notice as you start adding more and more resources into a template, that the deployments take longer. I often use the `--no-wait` flag to immediately return, and then I'll come back & check the status either in the CLI or the portal.

```bash
# Deploy without waiting for everything to complete
az group deployment create -g trash1 --template-file template.json --parameters @parameters.json --no-wait

# Get the last deployment for the resource group
az group deployment list -g trash1 --top 1
```

### Resources

I've introduced a load balancer to route ports 50000-50255 to port 22 on the various VM's. So I can SSH in by doing

```bash
# SSH into a node via the inbound NAT pool
ssh noel@noelVMSS.southcentralus.cloudapp.azure.com -p 50000
```

### Updates

ARM templates are declarative, and the default Azure CLI behavior is to do incremental updates. So I'm going to scale up my VM Scale Set from 1 to 3 nodes. I'm just going to add an `instanceCount` parameter to my `parameters.json` file, just below the `adminPassword` parameter

```json
"instanceCount": {
  "value": 3
}
```

When I deploy again - same template, same parameters, Azure will keep all my existing resources and scale up my environment. Pretty cool!

## 4. VM Scale Sets + Options

Playing with settings is fun - I'm going to turn some knobs

### Resources

* I've added some Managed Disks in the `storageProfile` section of the VM Scale Set
* I'm using SSH keys now. To get yours, run `cat ~/.ssh/id_rsa.pub` in a Bash window. Check out PuTTY and its related tools to get your public key if you're all-Windows
* I'm using CoreOS this time, and it doesn't like the username "admin". Quirks like this happen often enough - I've found it's good to understand how templates really work to quickly adapt and move on

A lot of solutions are designed doing just this - VM Scale Sets, with various options. You could use a custom image, or you could run a startup task that loads software at runtime. There are plenty of extensions - telemetry, Docker, custom scripts, etc.

## 5. Service Fabric

A scalable set of virtual machines opens up the door for more interesting higher level scenarios. Azure Container Service and Service Fabric are just a couple that take advantage of this. Here, I'm going to play with Service Fabric and set up a secure cluster on top of a VM Scale Set.

> Both Service Fabric and Azure Container Service are a breeze to set up with PowerShell and the Azure CLI, respectively. For ACS, you can also generate your own ARM templates via [acs-engine](https://github.com/Azure/acs-engine). Looking at the templates generated by acs-engine is another great way to learn more about ARM Templates

### Deployment

Setting up the certs and secrets in Key Vault for Service Fabric ARM templates isn't exactly intuitive. I got frustrated and created a shell script, which you can find below

> #### [Create a Self-Signed Certificate in Key Vault for Service Fabric](5-ServiceFabric/prepCerts.sh) 
>  Make sure you have a Key Vault: 
> ```bash
> az keyvault create -n nobun-temp -g keyvault2 --enabled-for-deployment --enabled-for-disk-encryption --enabled-for-template-deployment
> ```
> Create a self-signed cert, wrap it in some JSON, and put it into Key Vault
> ```bash
> # Usage: ./prepCerts.sh VAULT_NAME CLUSTER_FQDN
> ./prepCerts.sh nobun-temp nobunsf.southcentralus.cloudapp.azure.com
> ```
> Copy the output of the script into the `parameters.json` file

### Parameters

The `sourceVaultValue`, `certificateUrlValue`, and `certificateThumbprint` parameters point to a Key Vault, and they are used to set up a secure cluster. This is notable, because it's actually ARM that is getting the secrets out of Key Vault and passing them into your VM's. 

This is pretty cool - I can secure these certs & secrets, and they never once had the risk of being checked into any of my JSON files.

### Variables

Variables don't have to be strings or numbers - they can be complex objects or arrays, like `uniqueStringArray0`

### Resources

* Service Fabric currently runs best on Windows, so I've switched to a Windows Server 2016 image
* Note the `extensionProfile` section of the VM Scale Set. Service Fabric installs as an extension. 
* I'm also collecting diagnostics to a separate storage account with the IaasDiagnostics (often referred to as WAD) extension
* Under `osProfile`, you'll see a new section for secrets. My certificate will be deployed from KeyVault into new instances, making it available to the cluster.
* I've got new Load Balancer configurations for RDP instead of SSH. Likewise, I'm exposing ports 19000 and 19080 so that PowerShell and browsers can access the cluster.
* Tags - tags are a way to group, search for, and filter resources in Azure. Here, the template is setting `resourceType` and `clusterName` so I can see everything related to this cluster at a glance

### Outputs

* I've added an additional output for the cluster management endpoint so I don't have to go look it up later.

## Learn More

* [Azure Portal](https://portal.azure.com) - Use the Azure Portal to walk through the create process, and then visit "Automation options" before hitting Create. This will show you the ARM template that would be used. It's a great way to learn what options are available
* [azure-quickstart-templates](https://github.com/Azure/azure-quickstart-templates) - You'll look here often for reference, to copy code, and then tweak to fit your particular use case
* [Azure REST API reference](https://docs.microsoft.com/en-us/rest/api/) - If you need the nitty gritty details of what properties or values are available for a given resource type, you'll likely find it here
* [Azure Resource Explorer](https://resources.azure.com/) - Not all properties are available in the portal to view or edit. And not all of them are always documented :( You'll be able to see the full details of what's coming across the wire and make some updates here
* [Azure Resource Manager Template Functions](https://docs.microsoft.com/en-us/azure/azure-resource-manager/resource-group-template-functions) - Don't try to memorize everything, but be aware of what's available and use this as a reference when you need it. VS Code tooling helps here too
* [Azure Resource Manager Documentation](https://docs.microsoft.com/en-us/azure/azure-resource-manager/) - There's a huge amount of information under the "How to" menu section. Again - it's good to know where to look when you get stuck