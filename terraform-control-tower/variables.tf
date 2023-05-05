
variable "lacework_url" {
  type        = string
  description = "Enter your Lacework URL. ie. account.lacework.net."
  validation {
    condition     = can(regex("(.+?).lacework.net", var.lacework_url))
    error_message = "Invalid Lacework URL."
  }
}

variable "lacework_access_key_id" {
  type        = string
  description = "The Lacework API Access Key ID contains alphanumeric characters and symbols only."
  validation {
    condition     = can(regex("^[-a-zA-Z0-9_]*$", var.lacework_access_key_id)) && length(var.lacework_access_key_id) != 0
    error_message = "The Lacework API Access Key ID contains alphanumeric characters and symbols only."
  }
}

variable "lacework_secret_key" {
  type        = string
  description = "The Lacework API Secret Key contains alphanumeric characters and symbols only."
  validation {
    condition     = can(regex("^[a-zA-Z0-9_]*$", var.lacework_secret_key)) && length(var.lacework_secret_key) != 0
    error_message = "The Lacework API Secret Key contains alphanumeric characters and symbols only."
  }
}

variable "capability_type" {
  type        = string
  description = "Enter the Lacework Control Tower StackSet type to use."
  validation {
    condition     = contains(["CloudTrail+Config", "Config"], var.capability_type)
    error_message = "Enter the Lacework Control Tower StackSet type to use."
  }
  default = "CloudTrail+Config"
}

variable "existing_accounts" {
  type        = string
  description = "Choose to monitor any existing accounts. SUSPENDED accounts are skipped."
  validation {
    condition     = contains(["Yes", "No"], var.existing_accounts)
    error_message = "Choose to monitor any existing accounts. SUSPENDED accounts are skipped."
  }
  default = "Yes"
}

variable "existing_cloud_trail" {
  type        = string
  description = "Enter your existing AWS Control Tower CloudTrail name."
  validation {
    condition     = can(regex("^[a-zA-Z0-9_]*$", var.existing_cloud_trail)) && length(var.existing_cloud_trail) != 0
    error_message = "Invalid CloudTrail name."
  }
}

variable "kms_key_identifier_arn" {
  type        = string
  description = "Provide the ARN of the KMS key for decrypting S3 log files decryption if necessary. Ensure that the Lacework account or role has kms:decrypt access within the Key Policy. Won't use KMS decrypt if no key provided."
  validation {
    condition     = length(var.kms_key_identifier_arn) < 256 && length(var.kms_key_identifier_arn) != 0
    error_message = "Invalid key arn."
  }
}

variable "log_account_name" {
  type        = string
  description = "Enter your AWS Control Tower log account name."
  validation {
    condition     = can(regex("^[a-zA-Z0-9_]*$", var.log_account_name)) && length(var.log_account_name) != 0
    error_message = "The account name contains alphanumeric characters only."
  }
}

variable "audit_account_name" {
  type        = string
  description = "Enter your AWS Control Tower audit account name."
  validation {
    condition     = can(regex("^[a-zA-Z0-9_]*$", var.audit_account_name)) && length(var.audit_account_name) != 0
    error_message = "The account name contains alphanumeric characters only."
  }
}
