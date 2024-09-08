variable "sddc_manager_username" {
  description = "Username used to authenticate against an SDDC Manager instance"
  default     = "administrator@vsphere.local"
}

variable "sddc_manager_password" {
  description = "Password used to authenticate against an SDDC Manager instance"
  default     = "VMw@re1!"
  sensitive   = true
}

variable "sddc_manager_host" {
  description = "Fully qualified domain name of an SDDC Manager instance"
  default     = "sfo-vcf01.sfo.rainpole.io"
}

variable "domain_name" {
  description = "VCF workload domain name"
  default     = "sfo-w01"
}

variable "server_url" {
  description = "MSFT CA server URL"
}

variable "ca_secret" {
  description = "Password used to authenticate against MSFT CA"
  sensitive   = true
}

variable "template_name" {
  description = "MSFT CA VCF Certificate Template"
}

variable "username" {
  description = "Username used to authenticate against MSFC CA"
}

variable "cert_email" {
  description = "Registered Email address for Certificate Request"
}

variable "rotation_frequency_minutes" {
  type    = number
}

variable "rotation_frequency_days" {
  type    = number
}
