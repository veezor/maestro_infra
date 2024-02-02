resource "aws_ecs_task_definition" "ecs_taskdefinition" {
  family = format("%s-%s-%s-%s", "${var.owner}", "${var.project}", "${var.environment}", "${var.identifier}")
  network_mode = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu = "256"
  memory = "512"

  execution_role_arn = var.execution_role_arn


  container_definitions = jsonencode([{
    name  = format("%s-%s", "${var.owner}", "${var.project}")
    image = "494558059907.dkr.ecr.us-east-1.amazonaws.com/fagianijunior-static-site-production:145820fe"
    cpu = 256
    memory = 512
    portMappings = [{
      containerPort = 3000,
      hostPort      = 3000,
      protocol      = "tcp"
    }],
    essential = true
    entryPoint = ["web"]
    logConfiguration = {
      "logDriver" = "awslogs",
      "options"   = {
        "awslogs-group" = format("/ecs/%s-%s-%s-%s", "${var.owner}", "${var.project}", "${var.environment}", "${var.identifier}"),
        "awslogs-region" = "us-east-1",
        "awslogs-stream-prefix" = "ecs"
      }
    }

  }])
}

resource "aws_ecs_service" "ecs_service" {
  name            = format("%s-%s-%s-%s", "${var.owner}", "${var.project}", "${var.environment}", "${var.identifier}")
  cluster         = var.cluster_id
  task_definition = aws_ecs_task_definition.ecs_taskdefinition.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    subnets = var.private_subnet_ids
    security_groups =[var.app_security_group_id]
  }
}