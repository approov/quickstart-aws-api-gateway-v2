# AWS API GATEWAY EXAMPLE

This example is for developers not familiar with AWS API Gateway who are looking for a step by step tutorial on how they can create an HTTP API project with an [Approov](https://approov.io) authorizer.

By following this example you will create an HTTP API that will act as a [Reverse Proxy](https://blog.approov.io/using-a-reverse-proxy-to-protect-third-party-apis) to a third party API. The proxy will only forward requests made by your mobile app.

The reverse proxy with an Approov authorizer that is built here can also be used in other circumstances where the target of a request needs to be protected from bots, scripts, or other malicious accesses. For example, the target could be an AWS Lambda function, or another backend, managed by you or someone else. The Approov authorizer integration steps will be the same no matter what type of backend the reverse proxy is configured to access.


## TOC - Table of Contents

* [Why?](#why)
* [How it Works?](#how-it-works)
* [Requirements](#requirements)
* [How to Follow the Instructions?](#how-to-follow-the-instructions)
* [Setup](#setup)
* [Api Gateway V2 Http Api](#api-gateway-v2-http-api)
* [Approov Token Authorizer Lambda Function](#approov-token-authorizer-lambda-fjunction)
* [Test your Approov Integration](#test-your-approov-integration)
* [Troubleshooting](#troubleshooting)


## Why?

To lock down your API server to your mobile app. Please read the brief summary in the [README](/README.md#why) at the root of this repo or visit our [website](https://approov.io/product.html) for more details.

[TOC](#toc---table-of-contents)


## How it works?

For more background, see the overview in the [README](/README.md#how-it-works) at the root of this repo.

[TOC](#toc---table-of-contents)

## Requirements

* [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html) - Will be used to create all the necessary resources in AWS.
* [Docker CLI](https://docs.docker.com/get-docker/) - Will be used to package the AWS lambda function.

This guide was tested with the following Operating Systems:

* Ubuntu 20.04
* MacOS Big Sur
* Windows 10 WSL2 - Ubuntu 20.04

[TOC](#toc---table-of-contents)


## How to Follow the Instructions

When following the instructions you have the option to do it using a helper bash script, `./stack`, or you can enter the individual commands for `docker` and `aws` CLIs by hand. For example:

The helper script, `./stack`:

```bash
./stack aws-apigw-add-authorizer
```

The `aws` command:

```bash
aws apigatewayv2 create-authorizer \
    --api-id ${AWS_HTTP_API_ID} \
    --authorizer-type REQUEST \
    --identity-source '$request.header.Approov-Token' \
    --name ${PREFIX}approov-${LAMBDA_LANG}-api-authorizer \
    --authorizer-uri "arn:aws:apigateway:${AWS_DEFAULT_REGION}:lambda:path/2015-03-31/functions/arn:aws:lambda:${AWS_DEFAULT_REGION}:${AWS_ACCOUNT_ID}:function:${PREFIX}approov-${LAMBDA_LANG}-lambda-authorizer/invocations" \
    --authorizer-payload-format-version '2.0' \
    --enable-simple-responses
```

> **NOTE:** The required variables (${VARIABLE_NAME}) in the `aws` command are defined in the `.env` file and others will be exported to the environment as we go through the instructions. For example the value for the `${AWS_HTTP_API_ID}` can only be known after we create the API, so it is not in the `.env` file, but you will see an instruction to export at the appropriate point.

Choose the one you feel more comfortable with, you will get the same outcome either way.

[TOC](#toc---table-of-contents)


## Setup

### Clone this Repo

Command:

```text
git clone https://github.com/approov/quickstart-aws-api-gateway-v2.git
cd quickstart-aws-api-gateway-v2
```

### Setup Placeholders as Environment Variables

* `AWS_DEFAULT_REGION` - This env var will override the region configured at `~/.aws/config` and will be used by several commands through this example.
* `AWS_ACCOUNT_ID` - MUST be your AWS account number. Use CLI command `aws sts get-caller-identity --query Account --output text` to print it if you are unsure.

#### Prepare the Env File

The `.env.example` file contains the initial set of variables that you need to export to the environment.

Copy the `.env.example` to `.env` with:

```bash
cp .env.example .env
```

Now customize the `.env` file for your setup by following the instructions in the comments for each env var.

>#### Approov Secret
>
>The lambda function will require an Approov secret.
>
>For **development** and **testing** purposes we will use a dummy Approov secret and provide it using an environment variable in the `.env` file. The dummy secret to use while following this guide is `h+CX0tOzdAAR9l15bWAqvq7w9olk66daIH+Xk+IAHhVVHszjDzeGobzNnqyRze3lw/WVyWrc2gZfh3XXfBOmww==`.
>
>For **production** it's preferred to use the AWS Secrets Manager to store the Approov secret as instructed [here](docs/API_GATEWAY_QUICKSTART.md#approov-secret). When you use the secrets manager there is no need to specify a value in the `.env` file.

Now, export all the env vars on the `.env` file to the environment with the following command:

```bash
export $(grep -v '^#' .env | xargs -0)
```

[TOC](#toc---table-of-contents)


## Approov Token Authorizer Lambda Function

The lambda function that checks the Approov token needs to be packaged as a docker image and pushed to the AWS Elastic Container Registry (ECR) in order to be able to create the AWS Lambda function that will then be used as a custom authorizer in the API Gateway V2. The [AWS docs](https://docs.aws.amazon.com/AmazonECR/latest/userguide/getting-started-cli.html) will be used as a reference to guide us through the process.

### The Docker Image for the Elastic Container Registry (ECR)

#### Docker Login

Execute one of the commands:

```bash
./stack aws-ecr-login
```

or

```bash
aws ecr get-login-password | sudo docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com
```

Output:

```text
Login Succeeded
```

> **NOTE:** If your login doesn't succeed it's probably because you forgot to export the environment variables or their values aren't correct.


#### Create the ECR Repository

Execute one of the commands:

```bash
./stack aws-ecr-create-repo python
```

or

```bash
aws ecr create-repository \
    --repository-name ${PREFIX}approov-${LAMBDA_LANG}-lambda-authorizer \
    --image-scanning-configuration scanOnPush=true \
    --image-tag-mutability MUTABLE
```

Output (some strings are altered to remove private values):

```json
{
    "repository": {
        "repositoryArn": "arn:aws:ecr:eu-west-1:<accountNo>:repository/<prefix>approov/python-lambda-authorizer",
        "registryId": "<accountNo>",
        "repositoryName": "<prefix>approov/python-lambda-authorizer",
        "repositoryUri": "<accountNo>.dkr.ecr.eu-west-1.amazonaws.com/<prefix>approov/python-lambda-authorizer",
        "createdAt": "2021-07-09T16:55:12+00:00",
        "imageTagMutability": "MUTABLE",
        "imageScanningConfiguration": {
            "scanOnPush": true
        },
        "encryptionConfiguration": {
            "encryptionType": "AES256"
        }
    }
}
```

#### Build the Docker Image

Execute one of the commands:

```bash
./stack build python
```

or

```bash
sudo docker build --tag ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/${PREFIX}approov-${LAMBDA_LANG}-lambda-authorizer ./lambda/${LAMBDA_LANG}
```

> **NOTE:** AWS only permits lambda functions from Docker images stored in ECR and so the tag for the image MUST use the ECR repository URI with the following form: `${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com`.

#### Test the Docker Image

##### Run it Locally

Execute one of the commands:

```bash
./stack run python
```

or

```bash
sudo docker run \
    --rm \
    --detach \
    --name approov-authorizer \
    -p 9000:8080 \
    -v ~/.aws:/root/.aws \
    --env-file .env \
    ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/${PREFIX}approov-${LAMBDA_LANG}-lambda-authorizer
```

If you change the code then you just need to execute `./stack reset` to execute the `build` and `run` docker commands.

##### Test with cURL Requests

The cURL requests issued here are for testing the authorizer, they do not use the full requests that would be required by API Gateway. Instead we just need the `approov-token` header thereby simulating the internal call made to the lambda authorizer function.

From the terminal, execute the following cURL requests.

###### Example for a valid Appproov Token:

```bash
curl -X POST "http://localhost:9000/2015-03-31/functions/function/invocations" -d '{"headers": {"approov-token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjQ3MDg2ODMyMDUuODkxOTEyfQ.c8I4KNndbThAQ7zlgX4_QDtcxCrD9cff1elaCJe9p9U"}}'
```

Output:

```json
{"isAuthorized":true,"context":{"approovTokenClaims":{"exp":4708683205.891912}}}
```

###### Example for an invalid Approov Token:

```bash
curl -X POST "http://localhost:9000/2015-03-31/functions/function/invocations" -d '{"headers": {"approov-token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjQ3MDg2ODMyMDUuODkxOTEyfQ._ZdLOZmK4KXSIpVlhOpHBgboSHHTWer-X6oLqFIDQWI"}}'
```

Output:

```json
{"isAuthorized":false,"context":{"approovTokenClaims":""}}
```

###### Example for when the Approov Token header is missing:

```bash
curl -X POST "http://localhost:9000/2015-03-31/functions/function/invocations" -d '{"headers": {}}'
```

Output:

```json
{"isAuthorized":false,"context":{"approovTokenClaims":""}}
```

##### Tail the Container Logs

If you are not obtaining the expected responses then you need to take a look at the container logs while you issue the cURL requests.

Open another terminal and execute one of the commands:

```bash
./stack logs
```

or

```bash
sudo docker logs --follow approov-authorizer
```

##### Destroy the Container

Now that testing is finished you need to stop and remove the container.

Execute one of the commands:

```bash
./stack destroy
```

or

```bash
sudo docker stop approov-authorizer
```

The container will be automatically removed by docker because it was started with the `--rm` flag.

#### Push the Docker Image to ECR

Execute one of the commands:

```bash
./stack aws-ecr-push python
```

or

```bash
sudo docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/${PREFIX}approov-${LAMBDA_LANG}-lambda-authorizer
```

Output:

```text
The push refers to repository [<accountNo>.dkr.ecr.eu-west-1.amazonaws.com/<prefix>approov/python-lambda-authorizer]
c353bb0e7460: Pushed
b5a3e8f60d44: Pushed
cd8b8bd90dd3: Pushed
c6aab6766b67: Pushed
327474b71641: Pushed
338b8286a654: Pushed
d6fa53d6caa6: Pushed
ebc8877d7cab: Pushed
2b6dea28a545: Pushed
1b728d9a04ef: Pushed
latest: digest: sha256:a2ca777d9c2e72d133e51bd7b603cdd2519cc4b673b8fe951af7c69be00bd661 size: 2412
```

### Create the AWS Lambda Function

#### Create the IAM Role for the AWS Lambda Function

Execute one of the commands:

```bash
./stack aws-iam-create-role
```

or

```bash
aws iam create-role \
    --role-name ${PREFIX}approov-lambda-execution-role \
    --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":["lambda.amazonaws.com"]},"Action":"sts:AssumeRole"}]}'
```

Output:

```json
{
    "Role": {
        "Path": "/",
        "RoleName": "<prefix>approov-lambda-execution-role",
        "RoleId": "AROAS62IWWQXINVDKM4MS",
        "Arn": "arn:aws:iam::<accountNo>:role/<prefix>approov-lambda-execution-role",
        "CreateDate": "2021-07-09T17:09:43+00:00",
        "AssumeRolePolicyDocument": {
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Effect": "Allow",
                    "Principal": {
                        "Service": [
                            "lambda.amazonaws.com"
                        ]
                    },
                    "Action": "sts:AssumeRole"
                }
            ]
        }
    }
}
```

#### Attach a Role Policy

Execute one of the commands:

```bash
./stack aws-iam-add-role-policy
```

or

```bash
aws iam attach-role-policy \
    --role-name ${PREFIX}approov-lambda-execution-role \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
```

No output for this command.

#### Create the Lambda Function

Execute one of the commands:

```bash
./stack aws-lambda-create python
```

or

```bash
aws lambda create-function \
    --function-name ${PREFIX}approov-${LAMBDA_LANG}-lambda-authorizer \
    --package-type Image \
    --code ImageUri=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/${PREFIX}approov-${LAMBDA_LANG}-lambda-authorizer:latest \
    --role arn:aws:iam::${AWS_ACCOUNT_ID}:role/${PREFIX}approov-lambda-execution-role
```

> **NOTE:** The `--code ImageUri` parameter needs to be of the form `image-name:tag`; both `image-name` and `tag` are required.

Output:

```json
{
    "FunctionName": "<prefix>approov-python-lambda-authorizer",
    "FunctionArn": "arn:aws:lambda:eu-west-1:<accountNo>:function:<prefix>approov-python-lambda-authorizer",
    "Role": "arn:aws:iam::<accountNo>:role/<prefix>approov-lambda-execution-role",
    "CodeSize": 0,
    "Description": "",
    "Timeout": 3,
    "MemorySize": 128,
    "LastModified": "2021-07-09T17:11:02.154+0000",
    "CodeSha256": "91c1ccd39b279edd5bd46cb83b3166a375cf697a57b525b883b55ff2ed871735",
    "Version": "$LATEST",
    "TracingConfig": {
        "Mode": "PassThrough"
    },
    "RevisionId": "b9b158b5-9b64-4fe5-bfe9-5376844df112",
    "State": "Pending",
    "StateReason": "The function is being created.",
    "StateReasonCode": "Creating",
    "PackageType": "Image"
}
```

#### Add Environment Variables

Once the lambda functions are created, around 30 seconds, you can add the environment variables to the configuration with one of the following commands:

```bash
./stack aws-lambda-add-env-vars
```

or

```bash
aws lambda update-function-configuration \
    --function-name ${PREFIX}approov-${LAMBDA_LANG}-lambda-authorizer \
    --environment "{\"Variables\": {\"APPROOV_BASE64_SECRET\": \"${APPROOV_BASE64_SECRET}\", \"APPROOV_BASE64_SECRET_STORAGE\": \"ENV_VAR\"}}"
```

Output:

```json
{
    "FunctionName": "<prefix>approov-python-lambda-authorizer",
    "FunctionArn": "arn:aws:lambda:eu-west-1:<accountNo>:function:<prefix>approov-python-lambda-authorizer",
    "Role": "arn:aws:iam::<accountNo>:role/<prefix>approov-lambda-execution-role",
    "CodeSize": 0,
    "Description": "",
    "Timeout": 3,
    "MemorySize": 128,
    "LastModified": "2021-07-09T17:12:38.616+0000",
    "CodeSha256": "91c1ccd39b279edd5bd46cb83b3166a375cf697a57b525b883b55ff2ed871735",
    "Version": "$LATEST",
    "Environment": {
        "Variables": {
            "APPROOV_BASE64_SECRET_STORAGE": "ENV_VAR",
            "APPROOV_BASE64_SECRET": "h+CX0tOzdAAR9l15bWAqvq7w9olk66daIH+Xk+IAHhVVHszjDzeGobzNnqyRze3lw/WVyWrc2gZfh3XXfBOmww=="
        }
    },
    "TracingConfig": {
        "Mode": "PassThrough"
    },
    "RevisionId": "ce065965-ea07-42f2-af15-b5935baea2f1",
    "State": "Active",
    "LastUpdateStatus": "Successful",
    "PackageType": "Image"
}
```

[TOC](#toc---table-of-contents)


## API Gateway V2 with HTTP API

API Gateway now has two major versions for the CLI and SDKs, [V1 and V2](https://docs.aws.amazon.com/apigateway/index.html). We will use V2.

There are also two further API versions, [HTTP APIs and REST APIs](https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-vs-rest.html). We will use the HTTP API that was introduced as part of API Gateway V2.


### The Third Party API Setup

To demonstrate Approov protection of a third party API using API Gateway as a reverse proxy, we need an API to protect. You can continue by using an API of your choice, however, those APIs that have a single base URL and that control access with an API key communicated in a header for each API request will work with the least adaptation. To create this quickstart we used a free account for the Kutt URL shortener API, [kutt.it](https://kutt.it). If you wish to copy this approach then you can [signup for a free account](https://kutt.it/login) with your email (no payment details are required). Once you have an account you can grab an API Key from the [settings page](https://kutt.it/settings).

After you have the base URL for your target API and your private API Key then it's time to export them to the environment:

```bash
export API_URL=https://kutt.it
export API_KEY=___YOUR_API_KEY_HERE___
```

### Create the HTTP API

Execute one of the commands:

```bash
./stack aws-apigw-create-http-api ${API_URL}
```

or

```bash
aws apigatewayv2 create-api \
    --name ${PREFIX}approov-kuttit-api \
    --protocol-type HTTP \
    --target ${API_URL} # or https://your.api.domain.com
```

Output:

```json
{
    "ApiEndpoint": "https://hd90tf50jj.execute-api.eu-west-1.amazonaws.com",
    "ApiId": "hd90tf50jj",
    "ApiKeySelectionExpression": "$request.header.x-api-key",
    "CreatedDate": "2021-07-09T17:13:28+00:00",
    "DisableExecuteApiEndpoint": false,
    "Name": "<prefix>approov/kuttit-api",
    "ProtocolType": "HTTP",
    "RouteSelectionExpression": "$request.method $request.path"
}
```

#### Export the API ID to the Environment

Several commands will need to use the API ID and so we also export that to an environment variable.

```bash
export AWS_HTTP_API_ID=hd90tf50jj
```

> **NOTE:**: Replace `hd90tf50jj` with your value for the `ApiId` in the output of the previous command.

### Add the API Key Header to the Request

To forward the requests to Kutt API we need to add the header `X-API-KEY` and we do that by updating the HTTP API integration configuration created by AWS as part of the previous step.

#### Get the Integration ID

First we need to get the API integration ID; execute one of the commands:

```bash
./stack aws-apigw-get-integrations
```

or

```bash
aws apigatewayv2 get-integrations --api-id ${AWS_HTTP_API_ID}
```

Output:

```json
{
    "Items": [
        {
            "ApiGatewayManaged": true,
            "ConnectionType": "INTERNET",
            "IntegrationId": "6rmua1i",
            "IntegrationMethod": "ANY",
            "IntegrationType": "HTTP_PROXY",
            "IntegrationUri": "https://kutt.it",
            "PayloadFormatVersion": "1.0",
            "TimeoutInMillis": 30000
        }
    ]
}
```

#### Export the Integration ID to the Environment

```bash
export AWS_HTTP_API_INTEGRATION_ID=6rmua1i
```

> **NOTE:**: Replace `6rmua1i` with your value for the `IntegrationId` in the output of the previous command.

#### Update the Integration

Next we update the integration so that it adds the header for the API key.

> **NOTE:** If you are not targeting the Kutt API then you need to make sure you are using the correct header name for communicating the API key.

Execute one of the commands:

```bash
./stack aws-apigw-update-integration
```

or

```bash
aws apigatewayv2 update-integration \
    --api-id ${AWS_HTTP_API_ID} \
    --integration-id ${AWS_HTTP_API_INTEGRATION_ID} \
    --request-parameters "{\"append:header.X-API-KEY\": \"${API_KEY}\"}"
```

Output:

```json
{
    "ApiGatewayManaged": true,
    "ConnectionType": "INTERNET",
    "IntegrationId": "6rmua1i",
    "IntegrationMethod": "ANY",
    "IntegrationType": "HTTP_PROXY",
    "IntegrationUri": "https://kutt.it",
    "PayloadFormatVersion": "1.0",
    "RequestParameters": {
        "append:header.X-API-KEY": "aaabbbbccccddddeeeeffffgggg"
    },
    "TimeoutInMillis": 30000
}

```

### Enable Logging

#### Create a Log Group

Execute one of the commands:

```bash
./stack aws-logs-create-group
```

or

```bash
aws logs create-log-group --log-group-name ${PREFIX}aws-api-gateway-approov

# The above command doesn't give us any output, but we can confirm with:
aws logs describe-log-groups --log-group-name-prefix ${PREFIX}aws-api-gateway-approov
```

Output:

```json
{
    "logGroups": [
        {
            "logGroupName": "<prefix>aws-api-gateway-approov",
            "creationTime": 1625850870291,
            "metricFilterCount": 0,
            "arn": "arn:aws:logs:eu-west-1:<accountNo>:log-group:<prefix>aws-api-gateway-approov:*",
            "storedBytes": 0
        }
    ]
}
```

### Enabling Logging for an API Stage

Execute one of the commands:

```bash
./stack aws-apigw-add-logs
```

or

```bash
aws apigatewayv2 update-stage \
    --api-id ${AWS_HTTP_API_ID} \
    --stage-name '$default' \
    --access-log-settings "{\"DestinationArn\": \"arn:aws:logs:${AWS_DEFAULT_REGION}:${AWS_ACCOUNT_ID}:log-group:${PREFIX}aws-api-gateway-approov:*\", \"Format\": \"\$context.identity.sourceIp - - [\$context.requestTime] '\$context.httpMethod \$context.routeKey \$context.protocol' \$context.status \$context.responseLength \$context.requestId \$context.authorizer.error\"}"
```

Output:

```json
{
    "AccessLogSettings": {
        "DestinationArn": "arn:aws:logs:eu-west-1:<accountNo>:log-group:<prefix>aws-api-gateway-approov",
        "Format": "$context.identity.sourceIp - - [$context.requestTime] '$context.httpMethod $context.routeKey $context.protocol' $context.status $context.responseLength $context.requestId $context.authorizer.error"
    },
    "ApiGatewayManaged": true,
    "AutoDeploy": true,
    "CreatedDate": "2021-07-09T17:13:28+00:00",
    "DefaultRouteSettings": {
        "DetailedMetricsEnabled": false
    },
    "DeploymentId": "s6gjtg",
    "LastDeploymentStatusMessage": "Successfully deployed stage with deployment ID 's6gjtg'",
    "LastUpdatedDate": "2021-07-09T17:15:30+00:00",
    "RouteSettings": {},
    "StageName": "$default",
    "StageVariables": {},
    "Tags": {}
}
```

Open the [CloudWatch web console](https://console.aws.amazon.com/cloudwatch/) and select your log group from the left pane to be able to see the logs for your API.

### Create the Authorizer

Execute one of the commands:

```bash
./stack aws-apigw-add-authorizer
```

or

```bash
aws apigatewayv2 create-authorizer \
    --api-id ${AWS_HTTP_API_ID} \
    --authorizer-type REQUEST \
    --identity-source '$request.header.Approov-Token' \
    --name ${PREFIX}approov-${LAMBDA_LANG}-api-authorizer \
    --authorizer-uri "arn:aws:apigateway:${AWS_DEFAULT_REGION}:lambda:path/2015-03-31/functions/arn:aws:lambda:${AWS_DEFAULT_REGION}:${AWS_ACCOUNT_ID}:function:${PREFIX}approov-${LAMBDA_LANG}-lambda-authorizer/invocations" \
    --authorizer-payload-format-version '2.0' \
    --enable-simple-responses
```

Output:

```json
{
    "AuthorizerId": "8uog0g",
    "AuthorizerPayloadFormatVersion": "2.0",
    "AuthorizerType": "REQUEST",
    "AuthorizerUri": "arn:aws:apigateway:eu-west-1:lambda:path/2015-03-31/functions/arn:aws:lambda:eu-west-1:<accountNo>:function:<prefix>approov-python-lambda-authorizer/invocations",
    "EnableSimpleResponses": true,
    "IdentitySource": [
        "$request.header.Approov-Token"
    ],
    "Name": "<prefix>approov-python-api-authorizer"
}
```

#### Export the Authorize ID to the Environment

```bash
export AWS_AUTHORIZER_ID=8uog0g
```

> **NOTE:**: Replace `8uog0g` with your value for the `AuthorizerId` in the output of the previous command.


### Add the Lambda Permissions for the Authorizer

Execute one of the commands:

```bash
./stack aws-lambda-add-permission
```

or

```bash
aws lambda add-permission \
    --function-name ${PREFIX}approov-${LAMBDA_LANG}-lambda-authorizer \
    --statement-id ${PREFIX}api-gateway-quickstart-lambda-permissions-01 \
    --action lambda:InvokeFunction \
    --principal apigateway.amazonaws.com \
    --source-arn "arn:aws:execute-api:${AWS_DEFAULT_REGION}:${AWS_ACCOUNT_ID}:${AWS_HTTP_API_ID}/authorizers/${AWS_AUTHORIZER_ID}"
```

Output:

```json
{
    "Statement": "{\"Sid\":\"<prefix>api-gateway-quickstart-lambda-permissions-01\",\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"apigateway.amazonaws.com\"},\"Action\":\"lambda:InvokeFunction\",\"Resource\":\"arn:aws:lambda:eu-west-1:<accountNo>:function:<prefix>approov-python-lambda-authorizer\",\"Condition\":{\"ArnLike\":{\"AWS:SourceArn\":\"arn:aws:execute-api:eu-west-1:<accountNo>:hd90tf50jj/authorizers/8uog0g\"}}}"
}
```

### Get the HTTP API Default Route ID

Execute one of the commands:

```bash
./stack aws-apigw-list-routes
```

or

```bash
aws apigatewayv2 get-routes --api-id ${AWS_HTTP_API_ID}
```

Output:

```json
{
    "Items": [
        {
            "ApiGatewayManaged": true,
            "ApiKeyRequired": false,
            "AuthorizationType": "NONE",
            "RouteId": "fq392nn",
            "RouteKey": "$default",
            "Target": "integrations/m5ilk1g"
        }
    ]
}
```

We will need the `RouteId` value `fq392nn` to use in the next step.

#### Export the Route ID to the Environment

```bash
export AWS_ROUTE_ID=fq392nn
```

> **NOTE:**: Replace `fq392nn` with your value for the `RouteId` in the output of the previous command.


### Add the Authorizer to the HTTP API Default Route

Execute one of the commands:

```bash
./stack aws-apigw-update-route
```

or

```bash
aws apigatewayv2 update-route \
    --api-id ${AWS_HTTP_API_ID} \
    --route-id ${AWS_ROUTE_ID} \
    --authorization-type CUSTOM \
    --authorizer-id ${AWS_AUTHORIZER_ID}
```

Output:

```json
{
    "Items": [
        {
            "ApiGatewayManaged": true,
            "ApiKeyRequired": false,
            "AuthorizationType": "NONE",
            "RouteId": "fq392nn",
            "RouteKey": "$default",
            "Target": "integrations/m5ilk1g"
        }
    ]
}
```

[TOC](#toc---table-of-contents)


## Test your Approov Integration

Example for a valid Approov Token. Here we call the Kutt API via the API Gateway reverse proxy we have configured. We add a valid Approov token and specify the target URL for the shortened link we want to be created. The authorizer we have configured will check the token and add the API key header required by the Kutt API.

> **NOTE:** For testing another target API, you should adjust the request as required. The provided token is signed with the dummy secret provided at the top of this document and is valid until Mar 2119.

```bash
curl -X POST "https://${AWS_HTTP_API_ID}.execute-api.${AWS_DEFAULT_REGION}.amazonaws.com/api/v2/links"  \
    --header "Content-Type: application/json" \
    --header 'Approov-Token: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjQ3MDg2ODMyMDUuODkxOTEyfQ.c8I4KNndbThAQ7zlgX4_QDtcxCrD9cff1elaCJe9p9U' \
    --data '{"target": "https://approov.io"}'
```

Output:

```json
{
    "id":"72379aec-5c7e-4092-b702-267fde3929de",
    "address":"YrRyLV",
    "banned":false,
    "password":false,
    "target":"https://approov.io",
    "visit_count":0,
    "created_at":"2021-08-04T16:29:05.990Z",
    "updated_at":"2021-08-04T16:29:05.990Z",
    "description":null,
    "expire_in":"2021-08-04T16:34:05.526Z",
    "link":"https://kutt.it/YrRyLV"
}
```

> **NOTE:** You can try the shortened link that was created, it should navigate to approov.io: [https://kutt.it/YrRyLV](https://kutt.it/YrRyLV]).

Example for an invalid Approov Token. We try the same request but use a different Approov token. The token has the same expiry time but it is not signed with the correct secret and so the Approov check in the authorizer will fail.

```bash
curl -iX POST "https://${AWS_HTTP_API_ID}.execute-api.${AWS_DEFAULT_REGION}.amazonaws.com/api/v2/links" \
    --header "Content-Type: application/json" \
    --header 'Approov-Token: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjQ3MDg2ODMyMDUuODkxOTEyfQ._ZdLOZmK4KXSIpVlhOpHBgboSHHTWer-X6oLqFIDQWI' \
    --data '{"target": "https://approov.io"}'
```

Output:

```text
HTTP/2 403
date: Wed, 30 Jun 2021 15:24:46 GMT
content-type: application/json
content-length: 23
apigw-requestid: BvrtujDgDoEEMqg=

{"message":"Forbidden"}
```

Example with a missing Approov Token header. Again a similar request, but if there is no token header, it will not pass the token check.

```bash
curl -iX POST "https://${AWS_HTTP_API_ID}.execute-api.${AWS_DEFAULT_REGION}.amazonaws.com/api/v2/links" \
    --header "Content-Type: application/json" \
    --data '{"target": "https://approov.io"}'
```

Output:

```text
HTTP/2 401
date: Wed, 30 Jun 2021 15:25:48 GMT
content-type: application/json
content-length: 26
apigw-requestid: Bvr3chAYjoEEPgg=

{"message":"Unauthorized"}
```

[TOC](#toc---table-of-contents)


## Troubleshooting

Please follow the [troubleshooting guide](/docs/APPROOV_TOKEN_QUICKSTART.md#troubleshooting) in the Approov quickstart.

[TOC](#toc---table-of-contents)


## Issues

If you find any issue while following our instructions then just report it [here](https://github.com/approov/quickstart-aws-api-gateway-v2/issues), with the steps to reproduce it, and we will sort it out and/or guide you to the correct path.

[TOC](#toc---table-of-contents)


## Useful Links

If you wish to explore the Approov solution in more depth, then why not try one of the following links as a jumping off point:

* [Approov Free Trial](https://approov.io/signup)(no credit card needed)
* [Approov Get Started](https://approov.io/product/demo)
* [Approov QuickStarts](https://approov.io/docs/latest/approov-integration-examples/)
* [Approov Docs](https://approov.io/docs)
* [Approov Blog](https://approov.io/blog/)
* [Approov Resources](https://approov.io/resource/)
* [Approov Customer Stories](https://approov.io/customer)
* [Approov Support](https://approov.zendesk.com/hc/en-gb/requests/new)
* [About Us](https://approov.io/company)
* [Contact Us](https://approov.io/contact)

[TOC](#toc---table-of-contents)
