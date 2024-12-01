terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.8.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "3.0.2"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

data "azuread_client_config" "current" {}

resource "azuread_group" "this" {
  display_name     = "ad-${var.environment}-admins"
  owners           = [data.azuread_client_config.current.object_id]
  security_enabled = true
}

resource "azuread_group_role_management_policy" "this" {
  group_id = azuread_group.this.object_id
  role_id  = "member"

  activation_rules {
    maximum_duration      = "PT9H"
    require_justification = true
    approval_stage {
      primary_approver {
        type      = "groupMembers"
        object_id = azuread_group.this.object_id
      }
    }
    require_approval = true
  }

  notification_rules {
    eligible_activations {
      approver_notifications {
        default_recipients = true
        notification_level = "Critical"
      }
    }
  }
}

resource "azuread_privileged_access_group_eligibility_schedule" "this" {
  group_id             = azuread_group_role_management_policy.this.group_id
  principal_id         = azuread_group.this.object_id
  assignment_type      = "member"
  permanent_assignment = true
}

data "azurerm_role_definition" "contributor" {
  name = "Contributor"
}

resource "azurerm_role_assignment" "contributor" {
  scope              = "/subscriptions/${var.subscription_id}"
  role_definition_id = data.azurerm_role_definition.contributor.id
  principal_id       = azuread_group_role_management_policy.this.group_id
}
