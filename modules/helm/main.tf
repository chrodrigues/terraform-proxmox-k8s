resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = "3.12.2"
  namespace  = "kube-system"

  set {
    name  = "replicas"
    value = var.prometheus_metrics_server_replicas
  }

}

resource "helm_release" "kube-prometheus" {
  name       = "kube-prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "67.9.0"


  set {
    name  = "prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues"
    value = "false"
  }

  set {
    name  = "namespaceOverride"
    value = "kube-prometheus"
  }

  set {
    name  = "prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues"
    value = "false"
  }

  set {
    name  = "prometheus.prometheusSpec.remoteWriteDashboards"
    value = false
  }

  set {
    name  = "prometheus.prometheusSpec.retention"
    value = var.prometheus_retention
  }

  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName"
    value = var.prometheus_storageclass_name
  }

  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage"
    value = var.prometheus_disk_size
  }

  set {
    name  = "grafana.adminPassword"
    value = var.grafana_password_admin
  }

  set {
    name  = "grafana.persistence.enabled"
    value = true
  }

  set {
    name  = "grafana.persistence.type"
    value = "sts"
  }

  set {
    name  = "grafana.persistence.storageClassName"
    value = var.grafana_storageclass_name
  }


  set {
    name  = "grafana.persistence.size"
    value = var.grafana_disk_size
  }

}

#TODO: add persistent storage and retention 30 days for prometheus