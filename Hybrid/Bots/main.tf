terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=2.62.0"
    }
    azuread = {
      version = "=1.5.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id            = var.botSubscriptionID
  client_id                  = var.botSubscriptionClientID
  client_secret              = var.botSubscriptionClientSecret
  tenant_id                  = var.botSubscriptionTenantID
  skip_provider_registration = true
}

#Create User App Registration
resource "azuread_application" "user_app_registration" {
  display_name               = "${var.baseResourceName}user"
  identifier_uris            = []
  reply_urls                 = []
  available_to_other_tenants = true
  oauth2_allow_implicit_flow = false
  type                       = "webapp/api"
}

resource "azuread_service_principal" "user_app_registration_sp" {
  application_id = azuread_application.user_app_registration.application_id
}

resource "random_string" "password_user_app_registration_sp" {
  length  = 32
  special = true
}

resource "azuread_application_password" "user_app_registration_sp_secret" {
  display_name          = "${var.baseResourceName}user"
  application_object_id = azuread_application.user_app_registration.object_id
  value                 = random_string.password_user_app_registration_sp.result
  end_date              = var.endDate
  depends_on = [
    azuread_service_principal.user_app_registration_sp
  ]
}

#Create Author App Registration
resource "azuread_application" "author_app_registration" {
  display_name               = "${var.baseResourceName}author"
  identifier_uris            = ["api://${var.domain}"]
  reply_urls                 = ["https://${var.domain}"]
  available_to_other_tenants = true
  oauth2_allow_implicit_flow = false
  type                       = "webapp/api"

  oauth2_permissions {
    admin_consent_description  = "Access the API as the current logged-in user"
    admin_consent_display_name = "Access the API as the current logged-in user"
    is_enabled                 = true
    type                       = "User"
    value                      = "access_as_user"
  }

  required_resource_access {
    resource_app_id = "00000003-0000-0000-c000-000000000000"

    resource_access {
      id   = "e1fe6dd8-ba31-4d61-89e7-88639da4683d"
      type = "Scope"
    }

    resource_access {
      id   = "a154be20-db9c-4678-8ab7-66f6cc099a59"
      type = "Scope"
    }

    resource_access {
      id   = "5f8c59db-677d-491f-a6b8-5f174b11ec1d"
      type = "Scope"
    }

    resource_access {
      id   = "88e58d74-d3df-44f3-ad47-e89edf4472e4"
      type = "Scope"
    }

    resource_access {
      id   = "df021288-bdef-4463-88db-98f22de89214"
      type = "Role"
    }

    resource_access {
      id   = "5b567255-7703-4780-807c-7be8301ae99b"
      type = "Role"
    }

    resource_access {
      id   = "9ce09611-f4f7-4abd-a629-a05450422a97"
      type = "Role"
    }
  }

  optional_claims {
    access_token {
      name                  = "upn"
      source                = null
      essential             = false
      additional_properties = []
    }
  }
}

resource "azuread_service_principal" "author_app_registration_sp" {
  application_id = azuread_application.author_app_registration.application_id
}

resource "random_string" "password_author_app_registration_sp" {
  length  = 32
  special = true
}

resource "azuread_application_password" "author_app_registration_sp_secret" {
  display_name          = "${var.baseResourceName}author"
  application_object_id = azuread_application.author_app_registration.object_id
  value                 = random_string.password_author_app_registration_sp.result
  end_date              = var.endDate
  depends_on = [
    azuread_service_principal.author_app_registration_sp
  ]
}

#Deploy Bots and App Insights
resource "azurerm_resource_group" "botResourceGroup" {
  name     = var.botResourceGroupName
  location = var.botRegion
  depends_on = [
    azuread_service_principal.author_app_registration_sp,
    azuread_service_principal.user_app_registration_sp
  ]
}

resource "azurerm_application_insights" "appinsights" {
  name                = "${var.baseResourceName}bot-app-insights"
  location            = var.botRegion
  resource_group_name = azurerm_resource_group.botResourceGroup.name
  application_type    = "web"
  depends_on = [
    azuread_service_principal.author_app_registration_sp,
    azuread_service_principal.user_app_registration_sp
  ]
}

resource "azurerm_bot_web_app" "user" {
  name                       = "${var.baseResourceName}user"
  location                   = "global"
  resource_group_name        = azurerm_resource_group.botResourceGroup.name
  sku                        = var.sku
  microsoft_app_id           = azuread_application.user_app_registration.id
  developer_app_insights_key = azurerm_application_insights.appinsights.instrumentation_key
  # kind = "sdk"
  display_name = "CompanyCommunicatorApp-User"
  # description = "Broadcast messages to multiple teams and people in one go"
  # iconUrl = "https://raw.githubusercontent.com/OfficeDev/microsoft-teams-company-communicator-app/master/Manifest/color.png"
  endpoint = "https://terraform-cc-app.azurewebsites.us/api/messages/author"
  depends_on = [
    azuread_service_principal.author_app_registration_sp,
    azuread_service_principal.user_app_registration_sp
  ]

}

resource "azurerm_bot_channel_ms_teams" "MsTeamsChannelUser" {
  bot_name            = azurerm_bot_web_app.user.name
  location            = var.botRegion
  resource_group_name = azurerm_resource_group.botResourceGroup.name
  depends_on = [
    azuread_service_principal.author_app_registration_sp,
    azuread_service_principal.user_app_registration_sp
  ]

}

resource "azurerm_bot_web_app" "author" {
  name                       = "${var.baseResourceName}author"
  location                   = "global"
  resource_group_name        = azurerm_resource_group.botResourceGroup.name
  sku                        = var.sku
  microsoft_app_id           = azuread_application.author_app_registration.id
  developer_app_insights_key = azurerm_application_insights.appinsights.instrumentation_key
  display_name               = "CompnayCommunicatorApp-Author"
  # description              = "Broadcast messages to multiple teams and people in one go"
  # iconUrl                  = "https://raw.githubusercontent.com/OfficeDev/microsoft-teams-company-communicator-app/master/Manifest/color.png"
  endpoint = "https://terraform-cc-app.azurewebsites.us/api/messages/author"
  depends_on = [
    azuread_service_principal.author_app_registration_sp,
    azuread_service_principal.user_app_registration_sp
  ]

}

resource "azurerm_bot_channel_ms_teams" "MsTeamsChannelAuthor" {
  bot_name            = azurerm_bot_web_app.author.name
  location            = var.botRegion
  resource_group_name = azurerm_resource_group.botResourceGroup.name
  depends_on = [
    azuread_service_principal.author_app_registration_sp,
    azuread_service_principal.user_app_registration_sp
  ]

}

