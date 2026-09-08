###############################################################################
# k8s.tf — Namespaces, a sample workload, and an NLB-backed Service
###############################################################################

# Namespaces: frontend + backend
resource "kubernetes_namespace" "app" {
  for_each = toset(var.namespaces)

  metadata {
    name = each.value

    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "environment"                  = var.environment
    }
  }

  # Wait for the control plane AND the node group; without nodes the Service
  # would come up but never get healthy targets.
  depends_on = [module.eks]
}

###############################################################################
# Sample deployment so the load balancer has something to route to.
# Drop this block if you deploy your app with Helm/ArgoCD instead — but then
# make sure the Service selector below matches your real pods.
###############################################################################

resource "kubernetes_deployment" "frontend" {
  metadata {
    name      = "frontend"
    namespace = kubernetes_namespace.app["frontend"].metadata[0].name
    labels = {
      app = "frontend"
    }
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "frontend"
      }
    }

    template {
      metadata {
        labels = {
          app = "frontend"
        }
      }

      spec {
        container {
          name  = "nginx"
          image = "public.ecr.aws/nginx/nginx:1.27-alpine"

          port {
            container_port = 80
            name           = "http"
          }

          resources {
            requests = {
              cpu    = "50m"
              memory = "64Mi"
            }
            limits = {
              cpu    = "200m"
              memory = "128Mi"
            }
          }

          readiness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 5
            period_seconds        = 10
          }
        }
      }
    }
  }
}

###############################################################################
# LoadBalancer Service -> provisions an AWS Network Load Balancer
###############################################################################

resource "kubernetes_service" "frontend" {
  metadata {
    name      = "frontend-lb"
    namespace = kubernetes_namespace.app["frontend"].metadata[0].name

    annotations = {
      # "nlb" tells the in-tree AWS cloud provider to create a Network Load
      # Balancer instead of a Classic ELB. (If you install the AWS Load
      # Balancer Controller, use "external" + nlb-target-type: ip instead.)
      "service.beta.kubernetes.io/aws-load-balancer-type" = "nlb"

      # Public NLB in the public subnets tagged kubernetes.io/role/elb.
      # Use "internal" to place it in the private subnets instead.
      "service.beta.kubernetes.io/aws-load-balancer-scheme" = "internet-facing"

      # Cross-zone balancing: even traffic spread across AZs.
      "service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled" = "true"
    }
  }

  spec {
    type = "LoadBalancer"

    selector = {
      app = "frontend"
    }

    port {
      name        = "http"
      port        = 80
      target_port = 80
      protocol    = "TCP"
    }
  }

  # Terraform blocks until AWS reports the LB hostname, so the output below
  # is populated on the first apply.
  wait_for_load_balancer = true

  depends_on = [kubernetes_deployment.frontend]
}
