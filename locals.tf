locals {
  csvfld = csvdecode(file("./csvdata.csv"))
  accounts = {
    for row in local.csvfld :
    "${row.AccountId}_${row.BudgetName}" => {
      # "${row.linked_accounts}_${row.BudgetName}" => {
      account_id = row.AccountId
      # linked_accounts = row.linked_accounts
      budget_name     = row.BudgetName
      budget_amount   = row.BudgetAmount
      alert_threshold = row.Alert1Threshold
      alert_trigger   = row.Alert1Trigger
      sns_topic_arn   = row.SNSTopicArn
      email           = trim(row.email, " ") # safe even if empty

      # linked_accounts = contains(keys(row), "linked_accounts") ? jsondecode(row.linked_accounts) : []
      # Account_id = contains(keys(row), "account_id") ? jsondecode(row.account_id) : []
      linked_accounts = try(
        jsondecode(row.linked_accounts),
        compact(split(",", replace(row.linked_accounts, " ", ""))),
        length(trimspace(coalesce(row.linked_accounts, ""))) == 12 ? [trimspace(row.linked_accounts)] : [],
        []
      )

    }

  }



  csv_hash = filemd5("./csvdata.csv")
}

output "csv_keys" {
  value = [for row in local.csvfld : keys(row)]
}
