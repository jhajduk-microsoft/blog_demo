variable "baseResourceName" {
  type        = string
  description = "The base resource name that will be concatenated with the resources deployed"
}
variable "infraResourceGroupName" {
  type        = string
  description = "The name of the resource group that will contain the Infra portion of the deployment"
}
variable "infraRegion" {
  type        = string
  description = "The Azure region of the deployment"
}
variable "storageAccountTier" {
  type        = string
  description = "The tier of the storage account used for resource logging/info. Standard."
  validation {
    condition = (
      contains(["Standard", "Premium"], var.storageAccountTier)
    )
    error_message = "Enter Standard or Premium for the storage account tier."
  }
}
variable "storageReplicationScheme" {
  type        = string
  description = "The replication scheme of the storage account"
  validation {
    condition = (
      contains(["LRS", "GRS"], var.storageReplicationScheme)
    )
    error_message = "Enter the storage replication scheme. E.G. LRS, GRS."
  }
}
variable "storageAccountName" {
  type        = string
  description = "The name of the storage account"
}
variable "appServiceTier" {
  type        = string
  description = "The tier of the app service"
  validation {
    condition = (
      contains(["Standard", "Premium"], var.appServiceTier)
    )
    error_message = "Enter the pricing tier for the App Service."
  }
}
variable "appServiceSize" {
  type        = string
  description = "The size of the app service"
}
variable "capacity" {
  type        = number
  description = "The capacity of the app service"
}
variable "alwaysOn" {
  type        = bool
  description = "Choose whether the app service is always on"
  validation {
    condition = (
      contains([true, false], var.alwaysOn)
    )
    error_message = "Enter true or false for the Always On feature."
  }
}
variable "domainName" {
  type        = list(string)
  description = "The domain name for the app service"
}
variable "senderUPNList" {
  type        = string
  description = "Semicolon-delimited list of the user principal names (UPNs) allowed to send messages."
}
variable "serviceBusSKU" {
  type        = string
  description = "The SKU for the service bus"
  validation {
    condition = (
      contains(["Basic", "Standard", "Premium"], var.serviceBusSKU)
    )
    error_message = "Enter the Service Bus SKU."
  }
}
variable "repoURL" {
  type        = string
  description = "The repo URL"
}
variable "branch" {
  type        = string
  description = "The name of the branch located at the repo URL address"

}
variable "environment" {
  type        = string
  description = "The name of the Azure Cloud that you want to deploy to. E.G. 'public', 'usgovernment'"
  validation {
    condition = (
      contains(["public", "usgovernment"], var.environment)
    )
    error_message = "The Terraform specific cloud envionment name. E.G. public, usgovernment."
  }
}
variable "infraSubscriptionID" {
  type      = string
  sensitive = true
}
variable "infraSubscriptionClientID" {
  type      = string
  sensitive = true
}
variable "infraSubscriptionClientSecret" {
  type      = string
  sensitive = true
}
variable "infraSubscriptionTenantID" {
  type      = string
  sensitive = true
}
variable "authorClientID" {
  type      = string
  sensitive = true
}
variable "userClientID" {
  type      = string
  sensitive = true
}
variable "authorSecret" {
  type      = string
  sensitive = true
}
variable "userSecret" {
  type      = string
  sensitive = true
}
