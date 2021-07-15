#!/bin/sh

set -eu

Show_Help() {
  cat <<EOF

  A bash script wrapper for Docker and AWS CLI.


  SYNOPSIS:

  $ ./stack <command> <argument>


  COMMANDS:

  aws-ecr-create-repo       Creates the repo to store the docker images:
                            $ ./stack aws-ecr-create-repo python

  aws-ecr-login             Login to your private AWS ECR registry:
                            $ ./stack aws-ecr-login

  aws-ecr-push              Pushes the docker image:
                            $ ./stack aws-ecr-push python

  aws-iam-create-role       Creates the IAM role for the Approov lambda
                            function:
                            $ ./stack aws-iam-create-role

  aws-iam-add-role-policy   Attaches a policy to the Approov lambda function
                            role:
                            $ ./stack aws-iam-add-role-policy

  aws-lambda-create         Creates the Approov lambda function:
                            $ ./stack aws-lambda-create python

  aws-lambda-add-env-vars   Updates the Approov Lambda configuration with
                            environment variables:
                            $ ./stack aws-lambda-env-vars

  aws-apigw-create-http-api Creates a HTTP API for shapes.approov.io or for
                            the given API domain:
                            $ ./stack aws-apigw-create-http-api
                            $ ./stack aws-apigw-create-http-api api.domain.com

  aws-logs-create-group     Creates a log group for the Approov API Gateway:
                            $ ./stack aws-logs-create-group

  aws-apigw-add-logs        Enables CloudWatch logs for the API:
                            $ ./stack aws-apigw-add-logs

  aws-apigw-add-authorizer  Creates an authorizer in the API Gateway:
                            $ ./stack aws-apigw-add-authorizer

  aws-lambda-add-permission Add the lambda permissions to the Authorizer:
                            $ ./stack aws-lambda-add-permission

  aws-apigw-list-routes     List all routes for the given API ID:
                            $ ./stack aws-apigw-list-routes

  aws-apigw-update-route    Add the authorizer to the default route:
                            $ ./stack aws-apigw-update-route

  build                     Builds the docker image:
                            $ ./stack build python

  run                       Runs in localhost the lambda function:
                            $ ./stack run python

  reset                     Builds a new docker image and runs it:
                            $ ./stack reset python

  logs                      Tails the container logs:
                            $ ./stack logs

  destroy                   Stops and removes the container:
                            $ ./stack destroy

EOF
}

Set_Docker_Image_Name() {
  LAMBDA_LANG="${1? Missing lambda programming language, e.g: $ ./stack run python}"
  REPOSITORY_NAME="${PREFIX}approov/${LAMBDA_LANG}-lambda-authorizer"
  IMAGE_NAME="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPOSITORY_NAME}:latest"
}

Docker_Build() {
  sudo docker build \
    --tag "${IMAGE_NAME}" \
    ./lambda/${LAMBDA_LANG}
}

Docker_Run() {
  sudo docker run \
    --rm \
    --detach \
    --name approov-authorizer \
    -p ${STACK_PORT:-9000}:8080 \
    -v ~/.aws:/root/.aws \
    --env-file .env \
    "${IMAGE_NAME}"
}

Docker_Logs() {
  sudo docker logs --follow approov-authorizer
}

Docker_Stop() {
  sudo docker stop approov-authorizer
}

AWS_ECR_Login() {
  aws ecr get-login-password | sudo docker login \
    --username AWS \
    --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
}

AWS_ECR_Create_Repository() {
  aws ecr create-repository \
    --repository-name "${REPOSITORY_NAME}" \
    --image-scanning-configuration scanOnPush=true \
    --image-tag-mutability MUTABLE
}

AWS_ECR_Push() {
  sudo docker push ${IMAGE_NAME}
}

AWS_IAM_Create_Role() {
  aws iam create-role \
    --role-name ${PREFIX}approov-lambda-execution-role \
    --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":["lambda.amazonaws.com"]},"Action":"sts:AssumeRole"}]}'
}

AWS_IAM_Attach_Role_Policy() {
  aws iam attach-role-policy \
    --role-name ${PREFIX}approov-lambda-execution-role \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
}

AWS_Lambda_Create() {
  aws lambda create-function \
    --function-name ${PREFIX}approov-${LAMBDA_LANG}-lambda-authorizer \
    --package-type Image \
    --code ImageUri=${IMAGE_NAME} \
    --role arn:aws:iam::${AWS_ACCOUNT_ID}:role/${PREFIX}approov-lambda-execution-role
}

AWS_Lambda_Add_Env_Vars() {
  aws lambda update-function-configuration \
    --function-name ${PREFIX}approov-${LAMBDA_LANG}-lambda-authorizer \
    --environment "{\"Variables\": {\"APPROOV_BASE64_SECRET\": \"${APPROOV_BASE64_SECRET}\", \"APPROOV_BASE64_SECRET_STORAGE\": \"ENV_VAR\"}}"
}

AWS_API_GATEWAY_V2_Create_Api() {
  aws apigatewayv2 create-api \
    --name ${PREFIX}approov-shapes-api \
    --protocol-type HTTP \
    --target "${1? Missing API Domain, e.g: your.api.domain.com}"
}

AWS_Logs_Create_Group() {
  aws logs create-log-group \
    --log-group-name ${LOG_GROUP}

  aws logs describe-log-groups \
    --log-group-name-prefix ${LOG_GROUP}
}

AWS_API_GATEWAY_V2_Add_Logs() {
  aws apigatewayv2 update-stage \
    --api-id ${AWS_HTTP_API_ID} \
    --stage-name '$default' \
    --access-log-settings "{\"DestinationArn\": \"arn:aws:logs:${AWS_REGION}:${AWS_ACCOUNT_ID}:log-group:${LOG_GROUP}:*\", \"Format\": \"\$context.identity.sourceIp - - [\$context.requestTime] '\$context.httpMethod \$context.routeKey \$context.protocol' \$context.status \$context.responseLength \$context.requestId \$context.authorizer.error\"}"
}

AWS_API_GATEWAY_V2_Add_Authorizer() {
  aws apigatewayv2 create-authorizer \
    --api-id ${AWS_HTTP_API_ID} \
    --authorizer-type REQUEST \
    --identity-source '$request.header.Approov-Token' \
    --name ${PREFIX}approov-${LAMBDA_LANG}-api-authorizer \
    --authorizer-uri "arn:aws:apigateway:${AWS_REGION}:lambda:path/2015-03-31/functions/arn:aws:lambda:${AWS_REGION}:${AWS_ACCOUNT_ID}:function:${PREFIX}approov-${LAMBDA_LANG}-lambda-authorizer/invocations" \
    --authorizer-payload-format-version '2.0' \
    --enable-simple-responses
}

AWS_Lambda_Add_Permission() {
  aws lambda add-permission \
    --function-name ${PREFIX}approov-${LAMBDA_LANG}-lambda-authorizer \
    --statement-id ${PREFIX}api-gateway-quickstart-lambda-permissions-01 \
    --action lambda:InvokeFunction \
    --principal apigateway.amazonaws.com \
    --source-arn "arn:aws:execute-api:${AWS_REGION}:${AWS_ACCOUNT_ID}:${AWS_HTTP_API_ID}/authorizers/${AWS_AUTHORIZER_ID}"
}

AWS_API_GATEWAY_V2_List_Routes() {
  aws apigatewayv2 get-routes \
    --api-id ${1? Missing the API ID}
}

AWS_API_GATEWAY_V2_Update_Route() {
  aws apigatewayv2 update-route \
    --route-id ${1? Missing the API Route ID} \
    --api-id ${2? Missing the API ID} \
    --authorizer-id ${3? Missing the API Authorizer ID} \
    --authorization-type CUSTOM
}

Main() {

  local PREFIX=example_
  local LAMBDA_LANG=python

  if [ -f ./.env ]; then
    . ./.env
  else
    printf "\n---> Missing .env file. Copy .env.example to .env and adjust values.\n\n"
    exit 1
  fi

  local LOG_GROUP=${PREFIX}aws-api-gateway-approov

  for input in "${@}"; do
    case "${input}" in
      "aws-ecr-login" )
        shift 1
        AWS_ECR_Login
        exit $?
        ;;

      "aws-ecr-create-repo" )
        shift 1
        Set_Docker_Image_Name "${@}"
        AWS_ECR_Create_Repository
        exit $?
        ;;

      "aws-ecr-push" )
        shift 1
        Set_Docker_Image_Name "${@}"
        AWS_ECR_Push
        exit $?
        ;;

      "aws-iam-create-role" )
        shift 1
        AWS_IAM_Create_Role
        exit $?
        ;;

      "aws-iam-add-role-policy" )
        shift 1
        AWS_IAM_Attach_Role_Policy
        exit $?
        ;;

      "aws-lambda-create" )
        shift 1
        Set_Docker_Image_Name "${@}"
        AWS_Lambda_Create
        exit $?
        ;;

      "aws-lambda-add-env-vars" )
        shift 1
        AWS_Lambda_Add_Env_Vars
        exit $?
        ;;

      "aws-apigw-create-http-api" )
        shift 1
        AWS_API_GATEWAY_V2_Create_Api "${1:-https://shapes.approov.io}"
        exit $?
        ;;

      "aws-logs-create-group" )
        shift 1
        AWS_Logs_Create_Group
        exit $?
        ;;

      "aws-apigw-add-logs" )
        shift 1
        AWS_API_GATEWAY_V2_Add_Logs
        exit $?
        ;;

      "aws-apigw-add-authorizer" )
        shift 1
        AWS_API_GATEWAY_V2_Add_Authorizer
        exit $?
        ;;

      "aws-lambda-add-permission" )
        shift 1
        AWS_Lambda_Add_Permission
        exit $?
        ;;

      "aws-apigw-list-routes" )
        shift 1
        AWS_API_GATEWAY_V2_List_Routes "${1:-${AWS_HTTP_API_ID}}"
        exit $?
        ;;

      "aws-apigw-update-route" )
        shift 1
        AWS_API_GATEWAY_V2_Update_Route \
          "${1:-${AWS_ROUTE_ID}}" \
          "${2:-${AWS_HTTP_API_ID}}" \
          "${3:-${AWS_AUTHORIZER_ID}}"
        exit $?
        ;;

      "build" )
        shift 1
        Set_Docker_Image_Name "${@}"
        Docker_Build "${@}"
        exit $?
        ;;

      "reset" )
        shift 1
        Set_Docker_Image_Name "${@}"
        Docker_Build "${@}"
        Docker_Run "${@}"
        exit $?
        ;;

      "run" )
        shift 1
        Set_Docker_Image_Name "${@}"
        Docker_Run "${@}"
        exit $?
        ;;

      "logs" )
        shift 1
        Docker_Logs "${@}"
        exit $?
        ;;

      "destroy" )
        shift 1
        Docker_Stop
        exit $?
        ;;

      * )
        Show_Help
        exit $?
    esac
  done

  Show_Help
}

Main "${@:-help}"
