data "azurerm_resource_group" "rg" {
  name     = "aks-hello-world-poc"
}

locals {
  tags = {
    "Owner 1"         : "agreenwald@westmonroe.com"
    "Owner 2"         : "None"
    "Client Code"     : "Jepp-POC"
  }
  image = "wmpagreenwaldhelloworldacr.azurecr.io/helloworld-java:${var.image_tag}"
}

resource "azurerm_container_registry" "hello_world" {
  name                = "wmpagreenwaldhelloworldacr"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  sku                 = "Basic"

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = "aks-hello-world-cluster"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  dns_prefix          = "akshelloworld"

  default_node_pool {
    name            = "default"
    node_count      = 1
    vm_size         = "Standard_DS2_v2"
  }

  identity {
    type = "SystemAssigned"
  }

  tags                = local.tags
}

resource "azurerm_role_assignment" "this" {
  principal_id                     = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.hello_world.id
  skip_service_principal_aad_check = true
}

resource "kubernetes_namespace_v1" "hello_world_ns" {
  depends_on = [azurerm_role_assignment.this]
  metadata {
    name = "hello-world"
  }
}

resource "kubernetes_job_v1" "hello_world_job" {
  depends_on = [azurerm_role_assignment.this]

  metadata {
    name      = "hello-world-job"
    namespace = kubernetes_namespace_v1.hello_world_ns.metadata[0].name
  }

  spec {
    backoff_limit = 0

    template {
      metadata {
        labels = { app = "hello-world" }
      }

      spec {
        restart_policy = "Never"

        container {
          name  = "hello-world-container"
          image = local.image

          # optional, but helps avoid stale pulls if you ever reuse tags
          image_pull_policy = "Always"
        }
      }
    }
  }
}

