terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.27.0"
    }
  }
}
provider "aws" {
  #for_each = { for BudgetName in local.csvfld : BudgetName.BudgetName => BudgetName }
  #assume_role {
  #role_arn    = "arn:aws:iam::[each.valueAWSAccountNumber]:role/role_XXX"
  #external_id = "my_external_id"  
}