# Kubernetes Kubeadm Ansible Bootstrap (v1.35 / Modular Architecture)

Модульный набор Ansible плейбуков и ролей для автоматизированного развертывания производственного кластера Kubernetes **v1.35** на платформе VMware Cloud Director (vCD) и VMware vSphere через публичный интернет.

Проект разработан для совместной работы с Terraform-модулем [`tf-vcloud-k8s`](https://github.com/werton13/tf-vcloud-k8s).

---

## Архитектура плейбука

Развертывание кластера разделено на независимые этапы (`stage_plays/`), вызываемые из корневого `main.yaml`:

```
.
├── main.yaml                                         # Главный оркестратор выполнения
├── ansible.cfg                                       # Конфигурация Ansible (пути ролей, inventory)
├── requirements.yml                                  # Зависимости Galaxy (helm, kubernetes.core)
├── stage_plays/
│   ├── 02_wait_hosts_online.yaml                     # Ожидание доступности нод по SSH
│   ├── 03_configure_kubeapi_loadbalancer.yaml        # Настройка HAProxy/Keepalived (при необходимости)
│   ├── 04_configure_nodes_system.yaml                # Подготовка дисков LVM, OS тюнинг, containerd
│   ├── 05_install_mgmt_tools.yaml                    # Установка Helm и etcdctl на DVM и masters
│   ├── 06_install_k8s_binaries.yaml                  # Установка kubelet, kubeadm, kubectl из pkgs.k8s.io
│   ├── 07_create_k8s_cluster.yaml                    # Инициализация kubeadm, CNI, CSI, Ingress, Monitoring
│   ├── 08_configure_etcd_backup_on_masters.yaml      # Настройка локальных etcd-снапшотов
│   ├── 09_configure_etcd_on_dvm.yaml                  # Сбор etcd-снапшотов на DVM и настройка .kube/config
│   └── 10_list_k8s_nodes.yaml                        # Итоговая верификация статуса узлов
└── roles/
    ├── bootstrap_k8s_cluster                         # Инициализация kubeadm (v1beta4), надежный join нод
    ├── deploy_k8s_cni                                # Calico Tigera Operator (v3.29+)
    ├── deploy_k8s_csi                                # VMware Cloud Director Named Disk CSI Driver
    ├── dvm_config                                    # Настройка рабочей станции DVM (kubectl, helm, алиасы)
    ├── install_etcd_binaries                         # Установка etcdctl из GitHub Releases
    ├── install_helm                                  # Установка Helm 3 из get.helm.sh
    ├── install_k8s_binaries                          # Настройка pkgs.k8s.io и пакетов K8s
    ├── k8s_addons_ingress                            # NGINX Ingress Controller (публичный Helm-чарт)
    ├── k8s_addons_metrics                            # Kubernetes Metrics Server (публичный Helm-чарт)
    ├── k8s_addons_monitoring_v2                      # VictoriaMetrics стек (vmoperator, vmagent, scrapes)
    ├── k8s_dvm_gather_bkp                            # Сбор резервных копий etcd на DVM
    ├── k8s_mst_etcd_bkp                              # Скрипт etcd-снапшотов на master-нодах
    ├── k8s_patch_coredns                             # Патч CoreDNS для резолва vCloud API FQDN
    ├── prepare_k8s_nodes                             # Тюнинг ядра, containerd cgroup, audit policy
    ├── prepare_k8s_nodes_disks                       # LVM разметка /var и /var/lib
    └── wait_nodes                                    # Модуль ожидания готовности портов
```

---

## Особенности публичной версии

- **100% открытые источники:** Репозитории `pkgs.k8s.io`, `download.docker.com`, официальные публичные Helm-чарты (Kubernetes, VictoriaMetrics, Prometheus Community, Enix).
- **Спецификация kubeadm v1beta4:** Актуальный формат инициализации для Kubernetes 1.35.
- **Надежный механизм сборки:** Получение токена и CA-хеша через `kubeadm token create --print-join-command` и сертификатного ключа через `kubeadm init phase upload-certs` без хрупкого парсинга вывода консоли.
- **Graceful Disk Fallback:** Автоматическое обнаружение дисков `/dev/sdb` и `/dev/sdc` — если диски присутствуют, настраивается LVM, если ноды созданы с одним диском — плейбук продолжает работу без ошибок.
- **Декларативное управление:** Переменные передаются файлом `vars/cluster_vars.yaml`, генерируемым напрямую из Terraform.

---

## Запуск

Плейбук автоматически запускается через cloud-init на DVM-хосте:
```bash
ansible-playbook -i /K8s-inventory main.yaml -e @vars/cluster_vars.yaml
```

Для ручного перезапуска доступен скрипт:
```bash
/ansible_starter.sh
```
