provider "aws" {}

resource "aws_cloudformation_stack" "lacework_control_tower_integration" {
  name = "lacework-control-tower-integration"

  parameters = {
    LaceworkURL         = var.lacework_url
    LaceworkAccessKeyID = var.lacework_access_key_id
    LaceworkSecretKey   = var.lacework_secret_key
    CapabilityType      = var.capability_type
    ExistingAccounts    = var.existing_accounts
    ExistingCloudTrail  = var.existing_cloud_trail
    KMSKeyIdentifierARN = var.kms_key_identifier_arn
    LogAccountName      = var.log_account_name
    AuditAccountName    = var.audit_account_name
  }

  template_url = "https://lacework-alliances.s3.us-west-2.amazonaws.com/lacework-control-tower-cfn/templates/control-tower-integration.template.yml"

  capabilities = ["CAPABILITY_NAMED_IAM"]

}
