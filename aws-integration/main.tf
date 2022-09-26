provider "aws" {}

provider "lacework" {}

data "aws_caller_identity" "current" {}

module "lacework_aws_iam_role" {
  source  = "lacework/iam-role/aws"
  version = "0.2.3"
}

module "lacework_aws_config" {
  source  = "lacework/config/aws"
  version = "0.6.0"

  use_existing_iam_role = true
  iam_role_name         = module.lacework_aws_iam_role.name
  iam_role_arn          = module.lacework_aws_iam_role.arn
  iam_role_external_id  = module.lacework_aws_iam_role.external_id

  lacework_integration_name = "aws-config-${data.aws_caller_identity.current.account_id}"

}

module "lacework_aws_cloudtrail" {
  source  = "lacework/cloudtrail/aws"
  version = "2.3.0"

  use_existing_iam_role = true
  iam_role_name         = module.lacework_aws_iam_role.name
  iam_role_arn          = module.lacework_aws_iam_role.arn
  iam_role_external_id  = module.lacework_aws_iam_role.external_id

  lacework_integration_name = "aws-cloudtrail-${data.aws_caller_identity.current.account_id}"

  bucket_force_destroy = true # recommended for trial
}

module "lacework_aws_ecr" {
  source  = "lacework/ecr/aws"
  version = "0.7.1"

  use_existing_iam_role = true
  iam_role_name         = module.lacework_aws_iam_role.name
  iam_role_arn          = module.lacework_aws_iam_role.arn
  iam_role_external_id  = module.lacework_aws_iam_role.external_id

  lacework_integration_name = "aws-ecr-${data.aws_caller_identity.current.account_id}"
}


module "lacework_aws_agentless_scanning" {
  source  = "lacework/agentless-scanning/aws"
  version = "0.4.0"

  lacework_integration_name = "aws-agentless-scanning-${data.aws_caller_identity.current.account_id}"

  global   = true
  regional = true

  bucket_force_destroy = true # recommended for trial
}

module "eks_audit_log" {
  source  = "lacework/eks-audit-log/aws"
  version = "0.3.0"

  integration_name = "aws-eks-audit-log-${data.aws_caller_identity.current.account_id}"

  cloudwatch_regions = ["eu-central-1", "..."]
  cluster_names      = ["eks-cluster-a", "eks-cluster-b", "..."]

  bucket_force_destroy = true # recommended for trial
}
