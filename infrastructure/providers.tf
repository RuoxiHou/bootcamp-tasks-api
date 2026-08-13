terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.81"
    }

    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.10"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.38"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }

  subscription_id = var.subscription_id
}

provider "azapi" {}

provider "kubernetes" {
  host = data.azurerm_kubernetes_cluster.project3.kube_config[0].host

  username = data.azurerm_kubernetes_cluster.project3.kube_config[0].username

  password = data.azurerm_kubernetes_cluster.project3.kube_config[0].password

  client_certificate = base64decode(
    data.azurerm_kubernetes_cluster.project3.kube_config[0].client_certificate
  )

  client_key = base64decode(
    data.azurerm_kubernetes_cluster.project3.kube_config[0].client_key
  )

  cluster_ca_certificate = base64decode(
    data.azurerm_kubernetes_cluster.project3.kube_config[0].cluster_ca_certificate
  )
}

provider "helm" {
  kubernetes {
    host = data.azurerm_kubernetes_cluster.project3.kube_config[0].host

    username = data.azurerm_kubernetes_cluster.project3.kube_config[0].username

    password = data.azurerm_kubernetes_cluster.project3.kube_config[0].password

    client_certificate = base64decode(
      data.azurerm_kubernetes_cluster.project3.kube_config[0].client_certificate
    )

    client_key = base64decode(
      data.azurerm_kubernetes_cluster.project3.kube_config[0].client_key
    )

    cluster_ca_certificate = base64decode(
      data.azurerm_kubernetes_cluster.project3.kube_config[0].cluster_ca_certificate
    )
  }
}