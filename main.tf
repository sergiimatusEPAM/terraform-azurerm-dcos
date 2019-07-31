/**
 * [![Build Status](https://jenkins-terraform.mesosphere.com/service/dcos-terraform-jenkins/buildStatus/icon?job=dcos-terraform%2Fterraform-azurerm-dcos%2Fsupport%252F0.2.x)](https://jenkins-terraform.mesosphere.com/service/dcos-terraform-jenkins/job/dcos-terraform/job/terraform-azurerm-dcos/job/support%252F0.2.x/)
 *
 * Azure DC/OS
 * ==========
 * Deploy DC/OS on Azure using Terraform
 *
 * [Starting Guide](https://github.com/dcos-terraform/terraform-azurerm-dcos/blob/master/docs/published/README.md)
 *
 * Get started with using this module by reading the documentation here: [README.md](https://github.com/dcos-terraform/terraform-azurerm-dcos/tree/master/docs/README.md)
 *
 * Example
 * -------
 *
 *```hcl
 * module "dcos" {
 *   source  = "dcos-terraform/dcos/azurerm"
 *   version = "~> 0.2.0"
 *
 *   cluster_name = "mydcoscluster"
 *   infra_public_ssh_key_path = "~/.ssh/key.pub"
 *   admin_ips = ['198.51.100.0/24']
 *
 *   num_masters = "3"
 *   num_private_agentss = "2"
 *   num_public_agentss = "1"
 *
 *   dcos_cluster_docker_credentials_enabled =  "true"
 *   dcos_cluster_docker_credentials_write_to_etc = "true"
 *   dcos_cluster_docker_credentials_dcos_owned = "false"
 *   dcos_cluster_docker_registry_url = "https://index.docker.io"
 *   dcos_use_proxy = "yes"
 *   dcos_http_proxy = "example.com"
 *   dcos_https_proxy = "example.com"
 *   dcos_no_proxy = <<EOF
 *   # YAML
 *    - "internal.net"
 *    - "169.254.169.254"
 *   EOF
 *   dcos_overlay_network = <<EOF
 *   # YAML
 *       vtep_subnet: 44.128.0.0/20
 *       vtep_mac_oui: 70:B3:D5:00:00:00
 *       overlays:
 *         - name: dcos
 *           subnet: 12.0.0.0/8
 *           prefix: 26
 *   EOF
 *   dcos_rexray_config = <<EOF
 *   # YAML
 *     rexray:
 *       loglevel: warn
 *       modules:
 *         default-admin:
 *           host: tcp://127.0.0.1:61003
 *       storageDrivers:
 *       - ec2
 *       volume:
 *         unmount:
 *           ignoreusedcount: true
 *   EOF
 *   dcos_cluster_docker_credentials = <<EOF
 *   # YAML
 *     auths:
 *       'https://index.docker.io/v1/':
 *         auth: Ze9ja2VyY3licmljSmVFOEJrcTY2eTV1WHhnSkVuVndjVEE=
 *   EOF
 *
 *   # dcos_variant              = "ee"
 *   # dcos_license_key_contents = "${file("./license.txt")}"
 *   dcos_variant = "open"
 * }
 *```
 */

provider "azurerm" {}

resource "random_id" "id" {
  byte_length = 2
  prefix      = "${var.cluster_name}"
}

locals {
  cluster_name = "${var.cluster_name_random_string ? random_id.id.hex : var.cluster_name}"
}

module "dcos-infrastructure" {
  source  = "dcos-terraform/infrastructure/azurerm"
  version = "~> 0.2.0"

  cluster_name           = "${local.cluster_name}"
  infra_dcos_instance_os = "${var.dcos_instance_os}"
  ssh_public_key_file    = "${var.ssh_public_key_file}"

  bootstrap_image            = "${var.bootstrap_image}"
  bootstrap_vm_size          = "${var.bootstrap_vm_size}"
  bootstrap_dcos_instance_os = "${var.bootstrap_os}"
  bootstrap_disk_size        = "${var.bootstrap_root_volume_size}"
  bootstrap_disk_type        = "${var.bootstrap_root_volume_type}"

  masters_image            = "${var.masters_image}"
  masters_vm_size          = "${var.masters_vm_size}"
  masters_dcos_instance_os = "${var.masters_os}"
  masters_disk_size        = "${var.masters_root_volume_size}"
  masters_disk_type        = "Premium_LRS"

  private_agents_image            = "${var.private_agents_image}"
  private_agents_vm_size          = "${var.private_agents_vm_size}"
  private_agents_dcos_instance_os = "${var.private_agents_os}"
  private_agents_disk_size        = "${var.private_agents_root_volume_size}"
  private_agents_disk_type        = "${var.private_agents_root_volume_type}"

  public_agents_image            = "${var.private_agents_image}"
  public_agents_vm_size          = "${var.private_agents_vm_size}"
  public_agents_dcos_instance_os = "${var.private_agents_os}"
  public_agents_disk_size        = "${var.private_agents_root_volume_size}"
  public_agents_disk_type        = "${var.private_agents_root_volume_type}"
  public_agents_additional_ports = ["${var.public_agents_additional_ports}"]

  num_masters        = "${var.num_masters}"
  num_private_agents = "${var.num_private_agents}"
  num_public_agents  = "${var.num_public_agents}"
  admin_ips          = "${var.admin_ips}"
  subnet_range       = "${var.subnet_range}"

  location                          = "${var.location}"
  avset_platform_fault_domain_count = "${var.avset_platform_fault_domain_count}"
  tags                              = "${var.tags}"

  # If defining external exhibitor storage
  azurerm_storage_account_name = "${var.dcos_exhibitor_azure_account_name}"

  providers = {
    azurerm = "azurerm"
  }
}

module "dcos-core" {
  source  = "dcos-terraform/dcos-install-remote-exec/null"
  version = "~> 0.2.0"

  # ansible related config
  ansible_bundled_container = "${var.ansible_bundled_container}"
  ansible_additional_config = "${var.ansible_additional_config}"

  # bootstrap
  bootstrap_ip         = "${module.dcos-infrastructure.bootstrap.public_ip}"
  bootstrap_private_ip = "${module.dcos-infrastructure.bootstrap.private_ip}"
  bootstrap_os_user    = "${module.dcos-infrastructure.bootstrap.admin_username}"

  # master
  master_ips         = ["${module.dcos-infrastructure.masters.public_ips}"]
  master_private_ips = ["${module.dcos-infrastructure.masters.private_ips}"]
  masters_os_user    = "${module.dcos-infrastructure.masters.admin_username}"
  num_masters        = "${var.num_masters}"

  # private agent
  private_agent_ips         = ["${module.dcos-infrastructure.private_agents.public_ips}"]
  private_agent_private_ips = ["${concat(module.dcos-infrastructure.private_agents.private_ips,var.additional_private_agent_ips)}"]
  private_agents_os_user    = "${module.dcos-infrastructure.private_agents.admin_username}"
  num_private_agents        = "${var.num_private_agents}"

  # public agent
  public_agent_ips         = ["${module.dcos-infrastructure.public_agents.public_ips}"]
  public_agent_private_ips = ["${concat(module.dcos-infrastructure.public_agents.private_ips,var.additional_public_agent_ips)}"]
  public_agents_os_user    = "${module.dcos-infrastructure.public_agents.admin_username}"
  num_public_agents        = "${var.num_public_agents}"

  # Windows private agent
  windows_private_agent_private_ips = ["${var.additional_windows_private_agent_ips}"]
  windows_private_agent_passwords   = ["${var.additional_windows_private_agent_passwords}"]
  windows_private_agent_username    = "${var.additional_windows_private_agent_os_user}"

  # DC/OS options
  dcos_cluster_name                            = "${coalesce(var.dcos_cluster_name, local.cluster_name)}"
  custom_dcos_download_path                    = "${var.custom_dcos_download_path}"
  dcos_adminrouter_tls_1_0_enabled             = "${var.dcos_adminrouter_tls_1_0_enabled}"
  dcos_adminrouter_tls_1_1_enabled             = "${var.dcos_adminrouter_tls_1_1_enabled}"
  dcos_adminrouter_tls_1_2_enabled             = "${var.dcos_adminrouter_tls_1_2_enabled}"
  dcos_adminrouter_tls_cipher_suite            = "${var.dcos_adminrouter_tls_cipher_suite}"
  dcos_agent_list                              = "${var.dcos_agent_list}"
  dcos_audit_logging                           = "${var.dcos_audit_logging}"
  dcos_auth_cookie_secure_flag                 = "${var.dcos_auth_cookie_secure_flag}"
  dcos_aws_access_key_id                       = "${var.dcos_aws_access_key_id}"
  dcos_aws_region                              = "${var.dcos_aws_region}"
  dcos_aws_secret_access_key                   = "${var.dcos_aws_secret_access_key}"
  dcos_aws_template_storage_access_key_id      = "${var.dcos_aws_template_storage_access_key_id}"
  dcos_aws_template_storage_bucket             = "${var.dcos_aws_template_storage_bucket}"
  dcos_aws_template_storage_bucket_path        = "${var.dcos_aws_template_storage_bucket_path}"
  dcos_aws_template_storage_region_name        = "${var.dcos_aws_template_storage_region_name}"
  dcos_aws_template_storage_secret_access_key  = "${var.dcos_aws_template_storage_secret_access_key}"
  dcos_aws_template_upload                     = "${var.dcos_aws_template_upload}"
  dcos_bootstrap_port                          = "${var.dcos_bootstrap_port}"
  dcos_bouncer_expiration_auth_token_days      = "${var.dcos_bouncer_expiration_auth_token_days}"
  dcos_ca_certificate_chain_path               = "${var.dcos_ca_certificate_chain_path}"
  dcos_ca_certificate_key_path                 = "${var.dcos_ca_certificate_key_path}"
  dcos_ca_certificate_path                     = "${var.dcos_ca_certificate_path}"
  dcos_check_time                              = "${var.dcos_check_time}"
  dcos_cluster_docker_credentials              = "${var.dcos_cluster_docker_credentials}"
  dcos_cluster_docker_credentials_dcos_owned   = "${var.dcos_cluster_docker_credentials_dcos_owned}"
  dcos_cluster_docker_credentials_enabled      = "${var.dcos_cluster_docker_credentials_enabled}"
  dcos_cluster_docker_credentials_write_to_etc = "${var.dcos_cluster_docker_credentials_write_to_etc}"
  dcos_cluster_docker_registry_enabled         = "${var.dcos_cluster_docker_registry_enabled}"
  dcos_cluster_docker_registry_url             = "${var.dcos_cluster_docker_registry_url}"
  dcos_config                                  = "${var.dcos_config}"
  dcos_custom_checks                           = "${var.dcos_custom_checks}"
  dcos_customer_key                            = "${var.dcos_customer_key}"
  dcos_dns_bind_ip_blacklist                   = "${var.dcos_dns_bind_ip_blacklist}"
  dcos_dns_forward_zones                       = "${var.dcos_dns_forward_zones}"
  dcos_dns_search                              = "${var.dcos_dns_search}"
  dcos_docker_remove_delay                     = "${var.dcos_docker_remove_delay}"
  dcos_enable_docker_gc                        = "${var.dcos_enable_docker_gc}"
  dcos_enable_gpu_isolation                    = "${var.dcos_enable_gpu_isolation}"
  dcos_exhibitor_address                       = "${var.dcos_exhibitor_address}"
  dcos_exhibitor_azure_account_key             = "${var.dcos_exhibitor_azure_account_key}"
  dcos_exhibitor_azure_account_name            = "${var.dcos_exhibitor_azure_account_name}"
  dcos_exhibitor_azure_prefix                  = "${var.dcos_exhibitor_azure_prefix}"
  dcos_exhibitor_explicit_keys                 = "${var.dcos_exhibitor_explicit_keys}"
  dcos_exhibitor_storage_backend               = "${var.dcos_exhibitor_storage_backend}"
  dcos_exhibitor_zk_hosts                      = "${var.dcos_exhibitor_zk_hosts}"
  dcos_exhibitor_zk_path                       = "${var.dcos_exhibitor_zk_path}"
  dcos_fault_domain_detect_contents            = "${coalesce(var.dcos_fault_domain_detect_contents, file("${path.module}/scripts/fault-domain-detect.sh"))}"
  dcos_fault_domain_enabled                    = "${var.dcos_fault_domain_enabled}"
  dcos_gc_delay                                = "${var.dcos_gc_delay}"
  dcos_gpus_are_scarce                         = "${var.dcos_gpus_are_scarce}"
  dcos_http_proxy                              = "${var.dcos_http_proxy}"
  dcos_https_proxy                             = "${var.dcos_https_proxy}"
  dcos_ip_detect_contents                      = "${coalesce(var.dcos_ip_detect_contents,file("${path.module}/scripts/ip-detect.sh"))}"
  dcos_ip_detect_public_contents               = "${coalesce(var.dcos_ip_detect_public_contents,file("${path.module}/scripts/ip-detect-public.sh"))}"
  dcos_ip_detect_public_filename               = "${var.dcos_ip_detect_public_filename}"
  dcos_l4lb_enable_ipv6                        = "${var.dcos_l4lb_enable_ipv6}"
  dcos_license_key_contents                    = "${var.dcos_license_key_contents}"
  dcos_log_directory                           = "${var.dcos_log_directory}"
  dcos_master_discovery                        = "${var.dcos_master_discovery}"
  dcos_master_dns_bindall                      = "${var.dcos_master_dns_bindall}"
  dcos_master_external_loadbalancer            = "${coalesce(var.dcos_master_external_loadbalancer,module.dcos-infrastructure.lb.masters)}"
  dcos_master_list                             = ["${var.dcos_master_list}"]
  dcos_mesos_container_log_sink                = "${var.dcos_mesos_container_log_sink}"
  dcos_mesos_dns_set_truncate_bit              = "${var.dcos_mesos_dns_set_truncate_bit}"
  dcos_mesos_max_completed_tasks_per_framework = "${var.dcos_mesos_max_completed_tasks_per_framework}"
  dcos_no_proxy                                = "${var.dcos_no_proxy}"
  dcos_num_masters                             = "${var.dcos_num_masters}"
  dcos_oauth_enabled                           = "${var.dcos_oauth_enabled}"
  dcos_overlay_config_attempts                 = "${var.dcos_overlay_config_attempts}"
  dcos_overlay_enable                          = "${var.dcos_overlay_enable}"
  dcos_overlay_mtu                             = "${var.dcos_overlay_mtu}"
  dcos_overlay_network                         = "${var.dcos_overlay_network}"
  dcos_package_storage_uri                     = "${var.dcos_package_storage_uri}"
  dcos_previous_version                        = "${var.dcos_previous_version}"
  dcos_previous_version_master_index           = "${var.dcos_previous_version_master_index}"
  dcos_process_timeout                         = "${var.dcos_process_timeout}"
  dcos_public_agent_list                       = "${var.dcos_public_agent_list}"
  dcos_resolvers                               = ["${var.dcos_resolvers}"]
  dcos_rexray_config                           = "${var.dcos_rexray_config}"
  dcos_rexray_config_filename                  = "${var.dcos_rexray_config_filename}"
  dcos_rexray_config_method                    = "${var.dcos_rexray_config_method}"
  dcos_s3_bucket                               = "${var.dcos_s3_bucket}"
  dcos_s3_prefix                               = "${var.dcos_s3_prefix}"
  dcos_security                                = "${var.dcos_security}"
  dcos_skip_checks                             = "${var.dcos_skip_checks}"
  dcos_staged_package_storage_uri              = "${var.dcos_staged_package_storage_uri}"
  dcos_superuser_password_hash                 = "${var.dcos_superuser_password_hash}"
  dcos_superuser_username                      = "${var.dcos_superuser_username}"
  dcos_telemetry_enabled                       = "${var.dcos_telemetry_enabled}"
  dcos_variant                                 = "${var.dcos_variant}"
  dcos_ucr_default_bridge_subnet               = "${var.dcos_ucr_default_bridge_subnet}"
  dcos_use_proxy                               = "${var.dcos_use_proxy}"
  dcos_version                                 = "${var.dcos_version}"
  dcos_zk_agent_credentials                    = "${var.dcos_zk_agent_credentials}"
  dcos_zk_master_credentials                   = "${var.dcos_zk_master_credentials}"
  dcos_zk_super_credentials                    = "${var.dcos_zk_super_credentials}"
  dcos_enable_mesos_input_plugin               = "${var.dcos_enable_mesos_input_plugin}"
}
