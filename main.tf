data "vcf_domain" "domain1" {
  name = var.domain_name
}

data "vcf_certificate" "nsx_cert0" {
  domain_id     = data.vcf_domain.domain1.id
  resource_fqdn = data.vcf_domain.domain1.nsx_configuration[0].vip_fqdn
}

data "vcf_certificate" "vcenter_cert0" {
  domain_id     = data.vcf_domain.domain1.id
  resource_fqdn = data.vcf_domain.domain1.vcenter_configuration[0].fqdn
}

locals {
  nsx_manager_nodes    = data.vcf_domain.domain1.nsx_configuration[0].nsx_manager_node
  nsx_manager_node_map = { for idx, node in local.nsx_manager_nodes : idx => node }
  #nsx_manager_node_keys = [for k in local.nsx_manager_node_map : k]
  nsxm_certificate_map = {
    for idx, node in local.nsx_manager_node_map : idx => data.vcf_certificate.nsxm_certs[idx]
  }
}

data "vcf_certificate" "nsxm_certs" {
  for_each      = local.nsx_manager_node_map
  domain_id     = data.vcf_domain.domain1.id
  resource_fqdn = each.value.fqdn
}

resource "time_rotating" "rotate" {
  rotation_minutes = var.rotation_frequency_minutes
}

resource "time_rotating" "rotate_days" {
  rotation_days = var.rotation_frequency_days
}

resource "time_static" "rotate" {
  rfc3339 = time_rotating.rotate_days.rfc3339
}

resource "vcf_certificate_authority" "ca" {
  microsoft {
    secret        = var.ca_secret
    server_url    = var.server_url
    template_name = var.template_name
    username      = var.username
  }
  lifecycle { prevent_destroy = true }
}

resource "vcf_csr" "vcenter_csr" {
  domain_id         = data.vcf_domain.domain1.id
  country           = data.vcf_certificate.vcenter_cert0.certificate[0].subject_country
  fqdn              = data.vcf_domain.domain1.vcenter_configuration[0].fqdn
  email             = var.cert_email
  key_size          = data.vcf_certificate.vcenter_cert0.certificate[0].key_size
  locality          = data.vcf_certificate.vcenter_cert0.certificate[0].subject_locality
  state             = data.vcf_certificate.vcenter_cert0.certificate[0].subject_st
  organization      = data.vcf_certificate.vcenter_cert0.certificate[0].subject_org
  organization_unit = data.vcf_certificate.vcenter_cert0.certificate[0].subject_ou
  resource          = "VCENTER"
  lifecycle {
    replace_triggered_by = [
      time_static.rotate
    ]
  }
}

resource "vcf_csr" "nsx_csr" {
  domain_id         = data.vcf_domain.domain1.id
  country           = data.vcf_certificate.nsx_cert0.certificate[0].subject_country
  fqdn              = data.vcf_domain.domain1.nsx_configuration[0].vip_fqdn
  email             = var.cert_email
  key_size          = data.vcf_certificate.nsx_cert0.certificate[0].key_size
  locality          = data.vcf_certificate.nsx_cert0.certificate[0].subject_locality
  state             = data.vcf_certificate.nsx_cert0.certificate[0].subject_st
  organization      = data.vcf_certificate.nsx_cert0.certificate[0].subject_org
  organization_unit = data.vcf_certificate.nsx_cert0.certificate[0].subject_ou
  resource          = "NSXT_MANAGER"
  lifecycle {
    replace_triggered_by = [
      time_static.rotate
    ]
  }
}

resource "vcf_certificate" "vcenter_cert" {
  depends_on = [
    vcf_csr.vcenter_csr,
    vcf_certificate.nsx_cert
  ]
  csr_id = vcf_csr.vcenter_csr.id
  ca_id  = vcf_certificate_authority.ca.id
}

resource "vcf_certificate" "nsx_cert" {
  depends_on = [
    vcf_csr.nsx_csr
  ]
  csr_id = vcf_csr.nsx_csr.id
  ca_id  = vcf_certificate_authority.ca.id
}

resource "vcf_csr" "nsx_manager_csr" {
  for_each = local.nsxm_certificate_map

  country           = each.value.certificate[0].subject_country
  domain_id         = data.vcf_domain.domain1.id
  email             = "admin@vmware.com"
  fqdn              = each.value.resource_fqdn
  key_size          = each.value.certificate[0].key_size
  locality          = each.value.certificate[0].subject_locality
  organization      = each.value.certificate[0].subject_org
  organization_unit = each.value.certificate[0].subject_ou
  resource          = "NSXT_MANAGER"
  state             = each.value.certificate[0].subject_st

  lifecycle {
    replace_triggered_by = [
      time_static.rotate
    ]
    create_before_destroy = true
  }
}

resource "vcf_certificate" "nsx_manager_cert" {
  for_each = local.nsx_manager_node_map

  csr_id = vcf_csr.nsx_manager_csr[each.key].id
  ca_id  = vcf_certificate_authority.ca.id
}
