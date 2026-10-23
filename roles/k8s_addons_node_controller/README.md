# k8s_addons_node_controller

Installs the optional [`vcd-k8s-node-controller`](https://github.com/werton13/vcd-k8s-node-controller)
Helm chart when `node_controller_enabled` is `true`.

The role is disabled by default. Terraform passes the `node_controller_*`
variables through `vars/cluster_vars.yaml`.

## What it does

1. Verifies that Terraform ownership loss was acknowledged.
2. Creates the target namespace (unless `node_controller_create_namespace = false`).
3. Creates the vCD credentials Secret (unless `node_controller_create_vcd_secret = false`).
4. Adds the Helm repository and installs/upgrades the chart with the pinned
   image, tag, pull policy and existing Secret.

## Important

Once enabled, the controller and its `K8sWorkerPool` CRD own worker scaling and
worker LB pool membership. Do not use `terraform apply` to change worker count,
node configuration, or LB membership afterwards. Terraform is responsible only
for the initial bootstrap.

## Key variables

| Variable | Default | Purpose |
| --- | --- | --- |
| `node_controller_enabled` | `false` | Install the controller |
| `node_controller_acknowledge_terraform_ownership_loss` | `false` | Required when enabled |
| `node_controller_namespace` | `vcd-nodescale-system` | Release namespace |
| `node_controller_release_name` | `vcd-nodescale` | Helm release name |
| `node_controller_chart_repo` | `https://k8s-nodescale.github.io/vcd-k8s-node-controller` | Helm repository or OCI URL |
| `node_controller_chart_name` | `vcd-nodescale` | Chart name |
| `node_controller_chart_version` | `0.7.0` | Chart version |
| `node_controller_image_repository` | `docker.io/werton13/vcd-k8s-node-controller` | Controller image |
| `node_controller_image_tag` | `0.7.0` | Controller image tag |
| `node_controller_create_namespace` | `true` | Create the namespace |
| `node_controller_create_vcd_secret` | `true` | Create the vCD credentials Secret |
| `node_controller_vcd_secret_name` | `vcd-credentials` | Existing/new Secret name |
| `node_controller_vcd_user` | `""` | vCD service account |
| `node_controller_vcd_password` | `""` | vCD service account password |
| `node_controller_vcd_insecure` | `true` | Skip vCD TLS verification |
| `node_controller_helm_timeout` | `10m` | Helm timeout |
| `node_controller_helm_atomic` | `true` | Roll back failed installs |
| `node_controller_replica_count` | `1` | Controller replicas |
| `node_controller_node_selector` | control-plane label | Placement; control plane by default so the pool can reach zero |
| `node_controller_tolerations` | control-plane NoSchedule | Placement toleration |
| `node_controller_affinity` | `{}` | Extra affinity/podAntiAffinity |
| `node_controller_priority_class_name` | `system-cluster-critical` | Keeps the controller above the workloads it evicts |
| `node_controller_dns_policy` | empty | Empty keeps cluster DNS; `Default` if CoreDNS cannot run on a master |
