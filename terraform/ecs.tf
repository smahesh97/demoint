# ecs.tf

resource "aws_ecs_cluster" "main" {
  name = "cb-cluster"
}

resource "aws_ecs_task_definition" "app" {
  family                   = "cb-app-task"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.fargate_cpu
  memory                   = var.fargate_memory
  # container_definitions    = data.template_file.cb_app.rendered
  container_definitions    = <<TASK_DEFINITION
[
  {
"image":"${data.aws_ecr_repository.example.repository_url}:${data.external.current_image.result["image_tag"]}"
   }
]
TASK_DEFINITION 
}

data "external" "current_image" {
  program = ["bash", "./ecs-task.sh"]
}
output "get_new_tag" {
  value = data.external.current_image.result["image_tag"]
}
cat ECS-task.sh
#!/bin/bash
set -e
imageTag=$(aws ecr describe-images --repository-name <<here your repo name>> --query 'sort_by(imageDetails,& imagePushedAt)[-1].imageTags[0]')
imageTag=`sed -e 's/^"//' -e 's/"$//' <<<"$imageTag"`
jq -n --arg imageTag "$imageTag" '{"image_tag":$imageTag}'

exit 0
}

resource "aws_ecs_service" "main" {
  name            = "cb-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.app_count
  launch_type     = "FARGATE"

  network_configuration {
    security_groups  = [aws_security_group.ecs_tasks.id]
    subnets          = aws_subnet.private.*.id
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.app.id
    container_name   = "cb-app"
    container_port   = var.app_port
  }

  depends_on = [aws_alb_listener.front_end, aws_iam_role_policy_attachment.ecs_task_execution_role]
}


