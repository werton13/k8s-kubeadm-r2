# k8s_addons_node_controller_pool

Creates the initial `K8sWorkerPool` for the worker nodes Terraform provisioned,
so that a freshly bootstrapped cluster is immediately ready for scale-out
through the CRD.

The role runs from `stage_plays/11_create_node_controller_pool.yaml`, i.e. after
`10_list_k8s_nodes.yaml`: at that point every worker node is either `Ready` or
the bootstrap has already failed.

## What it does

1. Reads the `K8sWorkerPool` named `node_controller_pool_name` in
   `node_controller_pool_namespace`.
2. Renders `templates/pool.yaml.j2` and creates the pool **only if it does not
   exist yet**. An existing pool is never modified: a re-run of the playbook
   (or `terraform apply`) must not reset `spec.replicas` that an operator set
   through the CRD.
3. Waits until the controller has adopted the existing VMs: `Ready=True` and
   `status.observedReplicas == spec.replicas` (36 retries x 5s by default).
4. Prints the scale-out command for the operator.

The created object has `replicas = workers_count` and
`namePrefix = k8s_cluster_name`, so the controller adopts the existing worker
VMs instead of creating new ones.

## Requirements

- `kubernetes.core` collection (already in `requirements.yml`).
- `/etc/kubernetes/admin.conf` on the target master.
- The chart from `k8s_addons_node_controller` installed, i.e. the CRD
  `k8sworkerpools.infra.example.com` must exist.

## Key variables

| Variable | Default | Purpose |
| --- | --- | --- |
| `node_controller_enabled` | `false` | Stage is skipped entirely when false |
| `node_controller_create_pool` | `true` | Set to false to manage the pool manually |
| `node_controller_pool_namespace` | `default` | Namespace of the pool object |
| `node_controller_pool_name` | `{{ k8s_cluster_name \| lower }}` | Pool name |
| `node_controller_pool_token_ttl` | `1h` | Join token TTL |
| `node_controller_pool_min_replicas` | `1` | `scaleDown.minReplicas` |
| `node_controller_pool_ingress_port` | `30080` | `ingressPool.port` - the ingress controller **NodePort** pool members point at, not the virtual-server port |
| `node_controller_pool_ingress_edge` | `""` | `ingressPool.edge` - NSX-V edge gateway that owns the pool; needed to add/remove members |
| `node_controller_pool_worker_osdisk_gb` | from Terraform | `flavor.osDiskGB` - grows the cloned template system disk; without it a worker keeps the template disk (10 GB) |
| `node_controller_pool_ready_retries` | `36` | Convergence wait, attempts |
| `node_controller_pool_ready_delay` | `5` | Convergence wait, seconds |

The remaining `node_controller_pool_*` values (cloud-init data, flavor, disks,
`ipPlan`, catalog) are written by Terraform into
`group_vars/all/cluster_vars.yaml`.

## Scale out

```bash
kubectl -n default patch k8sworkerpool <cluster-name> --type merge \
  -p '{"spec":{"replicas":3}}'
```

Each new worker takes roughly five minutes (VM clone, cloud-init, kubelet join,
CNI, labels).

## Scale in / removing one worker

Decreasing `spec.replicas` removes the highest-ordinal worker. To remove a
specific worker, or to replace one:

```bash
# remove <cluster>-wrk-02 for good: the entry leaves deleteWorkers and
# replicas is decremented once the VM is gone, so it is not recreated
kubectl -n default patch k8sworkerpool <cluster-name> --type merge \
  -p '{"spec":{"scaleDown":{"deleteWorkers":["<cluster>-wrk-02"]}}}'

# replace <cluster>-wrk-03: drained and deleted, replicas unchanged, so the
# pool creates a new worker
kubectl annotate node <cluster>-wrk-03 infra.example.com/delete-worker=true
```

Every removal runs cordon -> ingress pool removal -> drain through the eviction
API -> VolumeAttachment wait -> power off the VM -> Node delete -> VM delete ->
address release. The guest is powered off before the Node object is deleted: a
Node deleted under a live kubelet re-registers itself within seconds and stays
behind as a `NotReady` object that nothing owns, whose pods are then never
garbage collected.
PodDisruptionBudgets are honoured (the API server refuses the eviction),
DaemonSet and mirror pods are skipped. The step is bounded by
`scaleDown.drainTimeout` (default 10m); when it expires the worker becomes
`Failed` and its VM is kept. `scaleDown.minReplicas` and the node-local PV
check (hostPath volumes used by the node, PVs pinned to it by nodeAffinity)
stop a removal that would destroy data; override the PV check with
`scaleDown.force: true` or the `infra.example.com/force-delete=true` node
annotation, never the PDB check.

## Ownership

The pool owns every VM named `<namePrefix>-wrk-*` in the vApp, including the
workers Terraform created - this role makes that explicit by creating the pool
with `replicas = workers_count` and `namePrefix = k8s_cluster_name`, so the
controller adopts the existing VMs instead of cloning new ones. There is no
read-only class of worker: anything in `status.nodes` is deletable through the
CRD.

Consequence: do not remove a bootstrap worker with `spec.scaleDown.deleteWorkers`.
Terraform still owns that VM in state and will re-create it at the same address
that the pool has already freed and may hand to another worker. Remove bootstrap
workers through Terraform (`workers.vm_count`) and lower `spec.replicas` in the
same change.

## Reconciliation policy (0.4.0)

`spec.reconciliation.policy` defaults to `Notify`: a worker that disappears
outside the control loop is reported (`Ready=False`, reason `WorkerMissing`,
slot and address kept reserved), not replaced. `AutoHeal` is an explicit
opt-in that recreates the missing worker in its own slot with the same name and
address. A `deleteWorkers` entry naming an already-absent worker is pruned and
`spec.replicas` is aligned with the observed count, so a removal of something
that is already gone never turns into a replacement.

## Placement and scale from zero (0.4.0)

Removing the last worker, or scaling a pool from 0 to N, needs the controller to
run outside the pool: a pass that deletes its own last host dies with it. The
supported topology is the control plane - the manager asks for 100m/512Mi, and
masters never match the `-wrk-` prefix, so they are not deletable through the
CRD. With that placement `node_controller_pool_min_replicas = 0` is valid; with
the controller on a worker the last worker is refused with
`LastWorkerProtected`.
