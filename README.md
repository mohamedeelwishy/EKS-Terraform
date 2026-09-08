# EKS Cluster — Terraform

Provisions a VPC (2 AZs, 2 public + 2 private subnets, single NAT), an EKS
cluster with a managed node group, IAM user `omar` bound via **EKS Access
Entries**, and Kubernetes namespaces + an NLB-backed Service.

## Layout

| File           | Contains                                                    |
| -------------- | ----------------------------------------------------------- |
| `providers.tf` | Terraform/provider versions, AWS + Kubernetes providers      |
| `network.tf`   | VPC module, subnets, NAT, Kubernetes discovery tags          |
| `eks.tf`       | EKS module, node group, IAM user `omar`, access entries      |
| `k8s.tf`       | Namespaces `frontend`/`backend`, sample deployment, NLB svc  |
| `variables.tf` | Inputs and shared locals                                     |
| `outputs.tf`   | Cluster endpoint, OIDC ARN, kubeconfig command, LB hostname  |

## Prerequisites

- Terraform >= 1.5
- AWS CLI v2 on `PATH` (the Kubernetes provider shells out to `aws eks get-token`)
- Credentials with permissions to create VPC / EKS / IAM resources

## Usage

```bash
terraform init
terraform plan
terraform apply

# then:
aws eks update-kubeconfig --region eu-west-1 --name demo-eks
kubectl get ns
kubectl -n frontend get svc frontend-lb
```

Tear down with `terraform destroy`. If it hangs on the VPC, the NLB created by
the Service is still deleting — Terraform removes the Service first, so give AWS
a minute and re-run.

## Notes

- `authentication_mode = "API"` means the cluster uses **only** access entries.
  The `aws-auth` ConfigMap is never created.
- `single_nat_gateway = true` is a cost optimisation. For production set it to
  `false` so one NAT per AZ survives an AZ outage.
- `cluster_endpoint_public_access_cidrs` defaults to `0.0.0.0/0`. Narrow it.
- The NLB is created by the in-tree AWS cloud provider. If you install the AWS
  Load Balancer Controller, switch the Service annotation to
  `aws-load-balancer-type: "external"` plus `aws-load-balancer-nlb-target-type: "ip"`.
- `omar` has no access keys. Create one (`aws iam create-access-key --user-name omar`)
  or, better, replace the user with an IAM role and let people assume it.
