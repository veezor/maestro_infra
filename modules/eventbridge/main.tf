resource "aws_cloudwatch_event_rule" "schedule" {
  for_each = { for idx in range(length(var.rule_name)) : idx => true }
  name                = format("%s-%s", var.identifier,  var.rule_name[each.key])
  description         = "Scheduled rule by Terraform"

  schedule_expression = "cron(${var.schedule_expression[each.key]})"
  tags = {
    "Owner"       = "${var.owner}"
    "Environment" = "${var.environment}"
    "Project"     = "${var.project}"
  }
}

resource "aws_cloudwatch_event_target" "example" {
  for_each = { for idx in range(length(var.rule_name)) : idx => true }
  arn  = var.target_arn[each.key]
  rule = aws_cloudwatch_event_rule.schedule[each.key].name
}