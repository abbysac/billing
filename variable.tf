variable "linked_account" {
  type = list(string)
  default = [
    "752338767189",
    "224761220970"
  ]
}

# variable "current_value" {
#   description = "The current value to compare against the threshold"
#   type        = number
#   default     = 0
# }

# variable "aws_region" {
#   description = "AWS region for SSM execution"
#   type        = string
#   default     = "us-east-1"
# }