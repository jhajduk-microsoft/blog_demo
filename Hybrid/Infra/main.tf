terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=2.56.0"
    }
    azuread = {
      version = "=1.4.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id            = var.infraSubscriptionID
  client_id                  = var.infraSubscriptionClientID
  client_secret              = var.infraSubscriptionClientSecret
  tenant_id                  = var.infraSubscriptionTenantID
  environment                = var.environment
  skip_provider_registration = true
}

#Base Infrastructure
resource "azurerm_resource_group" "ResourceGroup" {
  name     = var.infraResourceGroupName
  location = var.infraRegion
}

resource "azurerm_application_insights" "appinsights" {
  name                = "${var.baseResourceName}infra-app-insights"
  location            = var.infraRegion
  resource_group_name = azurerm_resource_group.ResourceGroup.name
  application_type    = "web"
}

resource "azurerm_storage_account" "storage_account" {
  name                      = var.storageAccountName
  resource_group_name       = azurerm_resource_group.ResourceGroup.name
  location                  = var.infraRegion
  account_tier              = var.storageAccountTier
  account_replication_type  = var.storageReplicationScheme
  account_kind              = "Storage"
  enable_https_traffic_only = true
  allow_blob_public_access  = false
}

resource "azurerm_app_service_plan" "server_farm" {
  name                = "${var.baseResourceName}appservice"
  location            = var.infraRegion
  resource_group_name = azurerm_resource_group.ResourceGroup.name
  kind                = "Windows"
  reserved            = false

  sku {
    tier     = var.appServiceTier
    size     = var.appServiceSize
    capacity = var.capacity
  }
}

#App Services
resource "azurerm_app_service" "communicator_bot_app_service" {
  lifecycle {
    ignore_changes = [
      source_control
    ]
  }
  name                    = "${var.baseResourceName}bot-service"
  location                = var.infraRegion
  resource_group_name     = azurerm_resource_group.ResourceGroup.name
  app_service_plan_id     = azurerm_app_service_plan.server_farm.id
  https_only              = true
  client_cert_enabled     = false
  client_affinity_enabled = true
  enabled                 = true

  site_config {
    always_on                = var.alwaysOn
    dotnet_framework_version = "v4.0"

    cors {
      support_credentials = true
      allowed_origins     = var.domainName
    }
  }

  app_settings = {
    "PROJECT"                        = "Source\\CompanyCommunicator\\Microsoft.Teams.Apps.CompanyCommunicator.csproj"
    "SITE_ROLE"                      = "app"
    "i18n:DefaultCulture"            = "en-us"
    "i18n:SupportedCultures"         = "en-us"
    "ProactivelyInstallUserApp"      = true
    "UserAppExternalId"              = var.userClientID
    "AzureAd:TenantId"               = var.infraSubscriptionTenantID
    "AzureAd:ClientId"               = var.authorClientID
    "AzureAd:ClientSecret"           = var.authorSecret
    "AzureAd:ApplicationIdURI"       = var.domainName[0]
    "UserAppId"                      = var.userClientID
    "UserAppPassword"                = var.userSecret
    "AuthorAppId"                    = var.authorClientID
    "AuthorAppPassword"              = var.authorSecret
    "StorageAccountConnectionString" = azurerm_storage_account.storage_account.primary_connection_string
    "ServiceBusConnection"           = azurerm_servicebus_namespace.service_bus.default_primary_connection_string
    "AllowedTenants"                 = var.infraSubscriptionTenantID
    "DisableTenantFilter"            = false
    "AuthorizedCreatorUpns"          = var.senderUPNList
    "DisableAuthentication"          = false
    "DisableCreatorUpnCheck"         = false
    "APPINSIGHTS_INSTRUMENTATIONKEY" = azurerm_application_insights.appinsights.instrumentation_key
    "WEBSITE_NODE_DEFAULT_VERSION"   = "10.15.2"
  }

  depends_on = [
    azurerm_storage_account.storage_account,
    azurerm_application_insights.appinsights
  ]
}

resource "azurerm_resource_group_template_deployment" "source_control_bindings_app_serivce" {

  name                = azurerm_app_service.communicator_bot_app_service.name
  resource_group_name = azurerm_resource_group.ResourceGroup.name
  deployment_mode     = "Incremental"
  template_content    = file("./source_control_bindings.json")
  parameters_content = jsonencode(
    {
      webSiteName = { value = azurerm_app_service.communicator_bot_app_service.name }
      repoUrl     = { value = var.repoURL }
      branch      = { value = var.branch }
      location    = { value = var.infraRegion }
    }
  )
}

resource "azurerm_function_app" "communicator_prep_app_service" {
  name                       = "${var.baseResourceName}prep-function"
  location                   = var.infraRegion
  resource_group_name        = azurerm_resource_group.ResourceGroup.name
  app_service_plan_id        = azurerm_app_service_plan.server_farm.id
  client_affinity_enabled    = false
  storage_account_name       = azurerm_storage_account.storage_account.name
  storage_account_access_key = azurerm_storage_account.storage_account.primary_access_key

  site_config {
    always_on = var.alwaysOn
  }

  app_settings = {
    "PROJECT"                                  = "Source\\CompanyCommunicator.Prep.Func\\Microsoft.Teams.Apps.CompanyCommunicator.Prep.Func.csproj"
    "SITE_ROLE"                                = "function"
    "i18n:DefaultCulture"                      = "en-us"
    "i18n:SupportedCultures"                   = "en-us"
    "ProactivelyInstallUserApp"                = true
    "UserAppExternalId"                        = var.userClientID
    "AzureWebJobsStorage"                      = azurerm_storage_account.storage_account.primary_connection_string
    "AzureWebJobsDashboard"                    = azurerm_storage_account.storage_account.primary_connection_string
    "FUNCTIONS_EXTENSION_VERSION"              = "~3"
    "FUNCTIONS_WORKER_RUNTIME"                 = "dotnet"
    "WEBSITE_CONTENTAZUREFILECONNECTIONSTRING" = azurerm_storage_account.storage_account.primary_connection_string
    "WEBSITE_CONTENTSHARE"                     = "${var.baseResourceName}prep-function"
    "APPINSIGHTS_INSTRUMENTATIONKEY"           = azurerm_application_insights.appinsights.instrumentation_key
    "AuthorAppId"                              = var.authorClientID
    "AuthorAppPassword"                        = var.authorSecret
    "UserAppId"                                = var.userClientID
    "UserAppPassword"                          = var.userSecret
    "TenantId"                                 = var.infraSubscriptionTenantID
    "StorageAccountConnectionString"           = azurerm_storage_account.storage_account.primary_connection_string
    "ServiceBusConnection"                     = azurerm_servicebus_namespace.service_bus.default_primary_connection_string

  }

  source_control {
    repo_url           = var.repoURL
    branch             = var.branch
    manual_integration = true
  }

  depends_on = [
    azurerm_storage_account.storage_account
  ]

}

resource "azurerm_function_app" "communicator_send_app_service" {
  name                       = "${var.baseResourceName}send-function"
  location                   = var.infraRegion
  resource_group_name        = azurerm_resource_group.ResourceGroup.name
  app_service_plan_id        = azurerm_app_service_plan.server_farm.id
  client_affinity_enabled    = false
  storage_account_name       = azurerm_storage_account.storage_account.name
  storage_account_access_key = azurerm_storage_account.storage_account.primary_access_key


  site_config {
    always_on = var.alwaysOn
  }

  app_settings = {
    "PROJECT"                                  = "Source\\CompanyCommunicator.Send.Func\\Microsoft.Teams.Apps.CompanyCommunicator.Send.Func.csproj"
    "SITE_ROLE"                                = "function"
    "i18n:DefaultCulture"                      = "en-us"
    "i18n:SupportedCultures"                   = "en-us"
    "AzureWebJobsStorage"                      = azurerm_storage_account.storage_account.primary_connection_string
    "AzureWebJobsDashboard"                    = azurerm_storage_account.storage_account.primary_connection_string
    "FUNCTIONS_EXTENSION_VERSION"              = "~3"
    "FUNCTIONS_WORKER_RUNTIME"                 = "dotnet"
    "WEBSITE_CONTENTAZUREFILECONNECTIONSTRING" = azurerm_storage_account.storage_account.primary_connection_string
    "WEBSITE_CONTENTSHARE"                     = "${var.baseResourceName}send-function"
    "APPINSIGHTS_INSTRUMENTATIONKEY"           = azurerm_application_insights.appinsights.instrumentation_key
    "MaxNumberOfAttempts"                      = "5"
    "UserAppId"                                = var.userClientID
    "UserAppPassword"                          = var.userSecret
    "StorageAccountConnectionString"           = azurerm_storage_account.storage_account.primary_connection_string
    "ServiceBusConnection"                     = azurerm_servicebus_namespace.service_bus.default_primary_connection_string

  }

  source_control {
    repo_url           = var.repoURL
    branch             = var.branch
    manual_integration = true
  }


  depends_on = [
    azurerm_storage_account.storage_account
  ]
}

resource "azurerm_function_app" "communicator_data_app_service" {
  name                       = "${var.baseResourceName}data-function"
  location                   = var.infraRegion
  resource_group_name        = azurerm_resource_group.ResourceGroup.name
  app_service_plan_id        = azurerm_app_service_plan.server_farm.id
  client_affinity_enabled    = true
  storage_account_name       = azurerm_storage_account.storage_account.name
  storage_account_access_key = azurerm_storage_account.storage_account.primary_access_key


  site_config {
    always_on = var.alwaysOn
  }

  app_settings = {
    "PROJECT"                                  = "Source\\CompanyCommunicator.Data.Func\\Microsoft.Teams.Apps.CompanyCommunicator.Data.Func.csproj"
    "SITE_ROLE"                                = "function"
    "i18n:DefaultCulture"                      = "en-us"
    "i18n:SupportedCultures"                   = "en-us"
    "AzureWebJobsStorage"                      = azurerm_storage_account.storage_account.primary_connection_string
    "AzureWebJobsDashboard"                    = azurerm_storage_account.storage_account.primary_connection_string
    "FUNCTIONS_EXTENSION_VERSION"              = "3"
    "FUNCTIONS_WORKER_RUNTIME"                 = "dotnet"
    "WEBSITE_CONTENTAZUREFILECONNECTIONSTRING" = azurerm_storage_account.storage_account.primary_connection_string
    "WEBSITE_CONTENTSHARE"                     = "${var.baseResourceName}send-function"
    "APPINSIGHTS_INSTRUMENTATIONKEY"           = azurerm_application_insights.appinsights.instrumentation_key
    "AuthorAppId"                              = var.authorClientID
    "AuthorAppPassword"                        = var.authorSecret
    "UserAppId"                                = var.userClientID
    "UserAppPassword"                          = var.userSecret
    "StorageAccountConnectionString"           = azurerm_storage_account.storage_account.primary_connection_string
    "ServiceBusConnection"                     = azurerm_servicebus_namespace.service_bus.default_primary_connection_string
    "CleanUpScheduleTriggerTime"               = "30 23 * * *"
    "CleanUpFile"                              = "1"
  }

  source_control {
    repo_url           = var.repoURL
    branch             = var.branch
    manual_integration = true
  }


  depends_on = [
    azurerm_storage_account.storage_account
  ]

}

#Service Bus an Queues
resource "azurerm_servicebus_namespace" "service_bus" {
  name                = "${var.baseResourceName}srvbus"
  location            = var.infraRegion
  resource_group_name = azurerm_resource_group.ResourceGroup.name
  sku                 = var.serviceBusSKU
}

resource "azurerm_servicebus_queue" "service_bus_send_queue" {
  name                                    = "${var.baseResourceName}send"
  resource_group_name                     = azurerm_resource_group.ResourceGroup.name
  namespace_name                          = azurerm_servicebus_namespace.service_bus.name
  lock_duration                           = "PT5M"
  max_size_in_megabytes                   = 1024
  requires_duplicate_detection            = false
  requires_session                        = false
  default_message_ttl                     = "P14D"
  dead_lettering_on_message_expiration    = false
  enable_batched_operations               = true
  duplicate_detection_history_time_window = "PT10M"
  max_delivery_count                      = 10
  status                                  = "Active"
  enable_partitioning                     = false
  enable_express                          = false
}

resource "azurerm_servicebus_queue" "service_bus_data_queue" {
  name                                    = "${var.baseResourceName}data"
  resource_group_name                     = azurerm_resource_group.ResourceGroup.name
  namespace_name                          = azurerm_servicebus_namespace.service_bus.name
  lock_duration                           = "PT5M"
  max_size_in_megabytes                   = 1024
  requires_duplicate_detection            = false
  requires_session                        = false
  default_message_ttl                     = "P14D"
  dead_lettering_on_message_expiration    = false
  enable_batched_operations               = true
  duplicate_detection_history_time_window = "PT10M"
  max_delivery_count                      = 10
  status                                  = "Active"
  enable_partitioning                     = false
  enable_express                          = false
}

resource "azurerm_servicebus_queue" "service_bus_prep_queue" {
  name                                    = "${var.baseResourceName}prep"
  resource_group_name                     = azurerm_resource_group.ResourceGroup.name
  namespace_name                          = azurerm_servicebus_namespace.service_bus.name
  lock_duration                           = "PT5M"
  max_size_in_megabytes                   = 1024
  requires_duplicate_detection            = false
  requires_session                        = false
  default_message_ttl                     = "P14D"
  dead_lettering_on_message_expiration    = false
  enable_batched_operations               = true
  duplicate_detection_history_time_window = "PT10M"
  max_delivery_count                      = 10
  status                                  = "Active"
  enable_partitioning                     = false
  enable_express                          = false
}

resource "azurerm_servicebus_queue" "service_bus_export_queue" {
  name                                    = "${var.baseResourceName}export"
  resource_group_name                     = azurerm_resource_group.ResourceGroup.name
  namespace_name                          = azurerm_servicebus_namespace.service_bus.name
  lock_duration                           = "PT5M"
  max_size_in_megabytes                   = 1024
  requires_duplicate_detection            = false
  requires_session                        = false
  default_message_ttl                     = "P14D"
  dead_lettering_on_message_expiration    = false
  enable_batched_operations               = true
  duplicate_detection_history_time_window = "PT10M"
  max_delivery_count                      = 10
  status                                  = "Active"
  enable_partitioning                     = false
  enable_express                          = false
}
