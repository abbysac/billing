# data "archive_file" "lambda" {
#   type        = "zip"
#   source_file = "lambda_function.py"
#   output_path = "lambda_function.zip"
# }

# Create a ZIP archive from the contents of the 'src' directory
data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "${path.module}/src"
  output_path = "${path.module}/lambda_function.zip"
}

data "archive_file" "ssm" {
  type        = "zip"
  source_dir  = "${path.module}/dev"
  output_path = "${path.module}/lambda_function_ssm.zip"
}



