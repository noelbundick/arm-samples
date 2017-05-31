# Azure Resource Manager Template Samples

A brief overview of ARM templates, and a few samples of increasing complexity

## Prerequisites

* [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
* [Azure subscription](https://azure.microsoft.com/en-us/free/)

### Recommended

* [Visual Studio Code](https://code.visualstudio.com/)
* [Azure Resource Manager Tools Extension](https://marketplace.visualstudio.com/items?itemName=msazurermtools.azurerm-vscode-tools)

## 0. Structure

Labeling this `0` because this doesn't actually do anything. But it shows the basic skeleton of a template, and it's worth knowing how to actually deploy a template

### Sections

Unfortunately, JSON doesn't allow comments, so I'll break down the interesting sections here

* Parameters: parameters can be passed into the template (names, instance counts, ports, etc). These can be given defaults and can be overridden multiple times (last one wins)
* Variables: variables can be used to help build your template. A common usage is to generate a unique string based on an input parameter.
* Resources: these are the things that will actually be created - things like VMs, SQL databases, Load Balancers, etc
* Outputs: outputs give you the ability to capture runtime values - such as the value of a dynamically allocated public IP

### How to Deploy

```bash
# Create a resource group to deploy to
az group create -n trash1 -l southcentralus

# Deploy the template and pass in parameters
# Note "@parameters.json" is not a typo, it tells the CLI to use the contents of the file rather than the string "parameters.json"
az group deployment create -g trash1 --template-file template.json --parameters @parameters.json
```

### Resources

* [Structure and Syntax](https://docs.microsoft.com/en-us/azure/azure-resource-manager/resource-group-authoring-templates)

## Resources

* [Azure Portal](https://portal.azure.com) - Use the Azure Portal to walk through the create process, and then visit "Automation options" before hitting Create. This will show you the ARM template that would be used. It's a great way to learn what options are available
* [azure-quickstart-templates](https://github.com/Azure/azure-quickstart-templates) - You'll look here often for reference, copy code, and then tweak to fit your particular use case
