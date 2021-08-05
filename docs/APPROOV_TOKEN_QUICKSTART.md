# Approov Token Quickstart

This quickstart is for developers familiar with Aws API Gateway who are looking for a quick intro on how they can add [Approov](https://approov.io) into an existing HTTP API project in the AWS API Gateway.


## TOC - Table of Contents

* [Why?](#why)
* [How it Works?](#how-it-works)
* [Requirements](#requirements)
* [AWS CLI Setup](#aws-cli-setup)
* [Approov Setup](#approov-setup)
* [Approov Token Check](#approov-token-check)
* [Test your Approov Integration](#test-your-approov-integration)
* [Troubleshooting](#troubleshooting)


## Why?

To lock down your API server to your mobile app. Please read the brief summary in the [README](/README.md#why) at the root of this repo or visit our [website](https://approov.io/product.html) for more details.

[TOC](#toc-table-of-contents)


## How it works?

For more background, see the overview in the [README](/README.md#how-it-works) at the root of this repo.


[TOC](#toc-table-of-contents)


## Requirements

To complete this quickstart you will need to already have an HTTP API created in the AWS API Gateway, and the AWS and Approov CLI(s) installed.

* [AWS APIGATEWAY HTTP API](https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-develop.html#http-api-examples.cli.quick-create) - If you don't have one yet you may want to follow instead the [AWS API Gateway Approov Example](/docs/AWS_API_GATEWAY_EXAMPLE.md).
* [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html) - Will be used to create all the necessary resources in AWS.
* [Docker CLI](https://docs.docker.com/get-docker/) - Will be used to package the AWS lambda function.
* [Approov CLI](https://approov.io/docs/latest/approov-installation/#approov-tool) - Will be used to retrieve the Approov Secret and configure the API.

This quickstart was tested in the following Operating Systems:

* Ubuntu 20.04
* MacOS Big Sur
* Windows 10 WSL2 - Ubuntu 20.04

[TOC](#toc-table-of-contents)


## AWS CLI Setup

When using the AWS CLI during this quickstart you will need to use several times some values, thus to make things easier you will set them as environment variables for your current shell session.

### How to Follow the Instructions

When following the instructions to execute the `aws` commands you will notice that some of them contain variables, for example:

```bash
aws lambda add-permission \
    --function-name approov-token-lambda-authorizer \
    --statement-id approov-lambda-permissions-01 \
    --action lambda:InvokeFunction \
    --principal apigateway.amazonaws.com \
    --source-arn "arn:aws:execute-api:${AWS_REGION}:${AWS_ACCOUNT_ID}:${AWS_HTTP_API_ID}/authorizers/${AWS_AUTHORIZER_ID}"
```

Some of the values for the variables in the above `aws` command are known by you before starting this quickstart, but others can only be known as you progress trough the instructions. For example, the `${AWS_AUTHORIZER_ID}` is only known after you have created the Authorizer.

The variables that you already know the values will be set on the next step, and the others will be set after you execute the command that outputs their value.

> **NOTE:** If you prefer to not set the variables used in the `aws` commands as environment variables then just replace each variable occurrence in a command with it's correspondent value.

### Setup the Environment Variables

* `AWS_REGION` - MUST be the same as configured at `~/.aws/config`. If you want o use another region then you also need to add it to each command `--region ___AWS_REGION_HERE___`.
* `AWS_ACCOUNT_ID` - MUST be the same you use to login into the AWS Web Console, but cannot be the alias.
* `AWS_HTTP_API_ID` - The ID for the HTTP API you want to protect with Approov. It can be retrieved from the AWS CLI with `aws apigatewayv2 get-apis`.
* `API_DOMAIN` - The domain for the API in the AWS API Gateway.
* `DOCKER_IMAGE_REGISTRY` - The URL for your private AWS Elastic Container Registry (ECR).
* `DOCKER_IMAGE_NAME` - The docker image name in the format `registry-url/repository:tag`.

On Linux and MAC:

```bash
# AWS_REGION=eu-west-2
export AWS_REGION=___YOUR_AWS_REGION_HERE___

# AWS_ACCOUNT_ID=1234567890
export AWS_ACCOUNT_ID=___YOUR_ACCOUNT_ID_HERE___

# AWS_HTTP_API_ID=kbjza06bsd
export AWS_HTTP_API_ID=___YOUR_HTTP_API_ID_HERE___

# API_DOMAIN=your.api.domain.com
export API_DOMAIN=___YOUR_HTTP_API_DOMAIN_HERE___

# DOCKER_IMAGE_REGISTRY=1234567890.dkr.ecr.eu-west-2.amazonaws.com
export DOCKER_IMAGE_REGISTRY=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

# DOCKER_IMAGE_NAME=1234567890.dkr.ecr.eu-west-2.amazonaws.com/approov-token-lambda-authorizer:13July2021_16h18m52s
export DOCKER_IMAGE_NAME=${DOCKER_IMAGE_REGISTRY}/approov-token-lambda-authorizer:$(date +%d%B%Y_%Hh%Mm%Ss)
```

## Approov Setup

To use Approov with the AWS API Gateway you need a small amount of configuration. First, Approov needs to know the API domain that will be protected. Second, the AWS API Gateway needs the Approov Base64 encoded secret that will be used to verify the tokens generated by the Approov cloud service.

### Approov Role

To use the Appoov CLI in the next steps you need to enable the role under which your username will run the commands. While the `approov api` command can be executed with a non admin role the `approov secret` command requires an [administration role](https://approov.io/docs/latest/approov-usage-documentation/#account-access-roles) to execute successfully.

Enable your Approov `admin` role with:

```bash
eval `approov role admin ___YOUR_APPROOV_USERNAME_HERE___`
approov role .
```

### Configure API Domain

Approov needs to know the domain name of the API for which it will issue tokens.

Add it with:

```bash
approov api -add ${API_DOMAIN}
```

> **NOTE:** When prompted authenticate with your `admin` password. This will create an authenticated session that will expire in 1 hour. After expiration you will be prompted again for that password when executing any of the Approov commands.

Adding the API domain also configures the [dynamic certificate pinning](https://approov.io/docs/latest/approov-usage-documentation/#approov-dynamic-pinning) setup, out of the box.

> **NOTE:** By default the pin is extracted from the public key of the leaf certificate served by the domain, as visible to the box issuing the Approov CLI command and the Approov servers.

### Approov Secret

Approov tokens are signed with a symmetric secret. To verify tokens, you need to grab the secret using the [Approov secret command](https://approov.io/docs/latest/approov-cli-tool-reference/#secret-command) and plug it into the AWS API Gateway environment to check the signatures of the [Approov Tokens](https://www.approov.io/docs/latest/approov-usage-documentation/#approov-tokens) that it processes.


#### AWS IAM Role

An IAM role will be necessary to setup and then access the Approov secret that will be stored in the AWS Secrets Manager.

##### Create the IAM Role

Execute the command:

```bash
aws iam create-role \
    --role-name approov-lambda-execution-role \
    --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":["lambda.amazonaws.com"]},"Action":"sts:AssumeRole"}]}'
```

The output will confirm the success of the operation.

##### Attach a Policy to the IAM Role

Execute the command:

```bash
aws iam attach-role-policy \
    --role-name approov-lambda-execution-role \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
```

No output for this command.

#### Set the Approov Secret in the AWS Secrets Manager

The preferred way to store the Approov secret is within the AWS Secrets Manager.

To set the Approov secret in the AWS Secrets Manager execute:

```bash
aws secretsmanager create-secret \
    --name APPROOV_BASE64_SECRET \
    --description "The base64 encoded secret retrieved with the Approov CLI." \
    --secret-string "$(approov secret -plain -get base64)"
```

Next, export the `ARN` from the command output with:

```bash
export APPROOV_BASE64_SECRET_AWS_ARN=___YOUR_AWS_ARN_HERE___
```

Now, set the permissions that will allow to access the secret from the lambda function:

```bash
aws secretsmanager put-resource-policy \
    --secret-id APPROOV_BASE64_SECRET \
    --resource-policy "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"AWS\":[\"arn:aws:iam::${AWS_ACCOUNT_ID}:role/approov-lambda-execution-role\"]},\"Action\":\"secretsmanager:GetSecretValue\",\"Resource\":\"${APPROOV_BASE64_SECRET_AWS_ARN}\"}]}"
```

The output will confirm the success of the operation.

[TOC](#toc-table-of-contents)


## Approov Token Check

To check the Approov token in any existing AWS API Gateway project you need to create a lambda function and add it as an Authorizer to your HTTP API.

The lambda function that checks the Approov token needs to be packaged as a docker image and pushed to the AWS Elastic Container Registry (ECR) in order to be able to create the AWS Lambda function that will then be used as a custom authorizer in the API Gateway. The [AWS docs](https://docs.aws.amazon.com/AmazonECR/latest/userguide/getting-started-cli.html) will be used as a reference to guide us through the process.

The Approov token its a JWT token, therefore the check is very simple and you can check how simple by inspecting the code for each supported programming language:

* [Python](/lambda/python/app.py) - Look up the code for the function `verifyJwtToken(approov_token)`
* [NodeJS](/lambda/nodejs/app.js) - Look up the code for the function `verifyJwtToken(approovToken)`.


### The Docker Image for the Elastic Container Registry (ECR)

#### Docker Login

Execute the command:

```bash
aws ecr get-login-password | sudo docker login ${DOCKER_IMAGE_REGISTRY} --username AWS --password-stdin
```

> **NOTE:** The use of `sudo` after a pipe requires that you already have an active `sudo` session, because you will not see the prompt for the `sudo` password and the command will fail. To force a a `sudo` login just execute the command `sudo docker`. The use of `sudo` may be not necessary to run docker commands on your system, but this depends on how your system is configured.

The output will confirm the success of the operation.

#### Create the ECR Repository

Execute the command:

```bash
aws ecr create-repository \
    --repository-name approov-token-lambda-authorizer \
    --image-scanning-configuration scanOnPush=true \
    --image-tag-mutability IMMUTABLE
```

The output will confirm the success of the operation.

#### Build the Docker Image

To build the docker image you will need to have this repo in your computer and be at it's root.

Execute this two commands:

```bash
git clone https://github.com/approov/quickstart-aws-api-gateway.git
cd quickstart-aws-api-gateway
```

Now, choose `python` or `nodejs` for the Approov lambda function implementation and execute the command:

```bash
sudo docker build --tag ${DOCKER_IMAGE_NAME} ./lambda/python # or nodejs
```

> **NOTE:** The `DOCKER_IMAGE_NAME` uses the ECR repository URI `${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com` because other Docker registries are not allowed by AWS when creating a lambda function from a docker image.

#### Test the Docker Image

##### Run the Container in Localhost

Execute the command:

```bash
sudo docker run \
    --rm \
    --detach \
    --name approov-authorizer \
    -p 9000:8080 \
    -e "LAMBDA_LOG_LEVEL=DEBUG" \
    -v ~/.aws:/root/.aws \
    ${DOCKER_IMAGE_NAME}
```

If later on you change the code for the lambda function then you need to:

* Update the tag for the image with `export DOCKER_IMAGE_NAME=${DOCKER_IMAGE_REGISTRY}/approov-token-lambda-authorizer:$(date +%d%B%Y_%Hh%Mm%Ss)`
* Execute again the docker commands `build` and `run`.

##### Test with cURL Requests

The request to be issued here is not the same request we would do to the API Gateway. Instead it is simulating the internal call made to the lambda authorizer function that requires an event that we provide on the body of the request in json format.

Now, let's do some basic tests to ensure that valid, invalid and missing tokens are handled properly and for that you just need to try the below cURL requests examples.

###### Example for a valid Appproov Token:

```bash
curl -X POST "http://localhost:9000/2015-03-31/functions/function/invocations" -d "{\"headers\": {\"approov-token\": \"$(approov token -type valid -genExample ${API_DOMAIN})\"}}"
```

Output:

```json
{"isAuthorized": true, "context": {"approovTokenClaims": {"exp": 1626266031, "ip": "1.2.3.4", "did": "ExampleApproovTokenDID=="}}}
```

###### Example for an invalid Approov Token:

```bash
curl -X POST "http://localhost:9000/2015-03-31/functions/function/invocations" -d "{\"headers\": {\"approov-token\": \"$(approov token -type invalid -genExample ${API_DOMAIN})\"}}"
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

If you are not obtaining the expected responses then you need to take a look to the container logs while you issue the cURL requests.

Open another terminal and execute the command:

```bash
sudo docker logs --follow approov-authorizer
```

##### Destroy the Container

Now that testing is finished you need to stop and remove the container.

Execute this command:

```bash
sudo docker stop approov-authorizer
```

The container will be automatically removed by docker because it was started with the flag `--rm`.

#### Push the Docker Image to ECR

Execute the command:

```bash
sudo docker push ${DOCKER_IMAGE_NAME}
```

### Create the Approov Lambda Function

Execute the command:

```bash
aws lambda create-function \
    --function-name approov-token-lambda-authorizer \
    --package-type Image \
    --code ImageUri=${DOCKER_IMAGE_NAME} \
    --role arn:aws:iam::${AWS_ACCOUNT_ID}:role/approov-lambda-execution-role
```

> **NOTE:** The `--code ImageUri` parameter needs to be like `image-name:tag`, otherwise it will fail without the tag.

The output will confirm the success of the operation.

[TOC](#toc-table-of-contents)


### Create the Approov Lambda Authorizer

Execute the command:

```bash
aws apigatewayv2 create-authorizer \
    --api-id ${AWS_HTTP_API_ID} \
    --authorizer-type REQUEST \
    --identity-source '$request.header.Approov-Token' \
    --name approov-token-api-authorizer \
    --authorizer-uri "arn:aws:apigateway:${AWS_REGION}:lambda:path/2015-03-31/functions/arn:aws:lambda:${AWS_REGION}:${AWS_ACCOUNT_ID}:function:approov-token-lambda-authorizer/invocations" \
    --authorizer-payload-format-version '2.0' \
    --enable-simple-responses
```

The output will confirm the success of the operation.

#### Export the Authorize ID to the Environment
j
```bash
export AWS_AUTHORIZER_ID=___YOUR_AUTHORIZER_ID_HERE___
```

> **NOTE:**: Replace `8uog0g` with your value for the `AuthorizerId` in the output of the previous command.


### Add the Lambda Permissions for the Authorizer

Execute the command:

```bash
aws lambda add-permission \
    --function-name approov-token-lambda-authorizer \
    --statement-id api-gateway-quickstart-lambda-permissions-01 \
    --action lambda:InvokeFunction \
    --principal apigateway.amazonaws.com \
    --source-arn "arn:aws:execute-api:${AWS_REGION}:${AWS_ACCOUNT_ID}:${AWS_HTTP_API_ID}/authorizers/${AWS_AUTHORIZER_ID}"
```

The output will confirm the success of the operation.

#### Add the Approov Authorizer to your HTTP API Routes

To list all your routes execute:

```bash
aws apigatewayv2 get-routes --api-id ${AWS_HTTP_API_ID}
```

Now, for each route you want to protect with Approov execute:

```bash
aws apigatewayv2 update-route \
    --api-id ${AWS_HTTP_API_ID} \
    --authorizer-id ${AWS_AUTHORIZER_ID} \
    --authorization-type CUSTOM \
    --route-id ___YOUR_ROUTE_ID_HERE___
```

The output will confirm the success of the operation.

[TOC](#toc-table-of-contents)


## Test your Approov Integration

The following examples below use cURL, but you can also use the [Postman Collection](/README.md#testing-with-postman) to make the API requests. Just remember that you need to adjust the urls and tokens defined in the collection to match your deployment. Alternatively, the README for the Postman Collection also contains instructions for using the preset _dummy_ secret to test your Approov integration.

### With Valid Approov Tokens

Make the cURL request to one of the routes you added the Approov authorizer:

```bash
curl -iX GET "https://${AWS_HTTP_API_ID}.execute-api.${AWS_REGION}.amazonaws.com" \
  --header "Approov-Token: $(approov token -type valid -genExample ${API_DOMAIN})"
```

> **NOTE**: If this command stays frozen, then the most probable cause is that your Approov CLI authenticated session has expired. Authenticate again as instructed in the Troubleshooting [section](#approov-cli-authentication-expired).

The request should be accepted. For example:

```json
HTTP/2 200
content-type: application/json; charset=utf-8
apigw-requestid: BvrXBhuAjoEEPSg=

{"key": "The response from your backend API"}
```

### With Invalid Approov Tokens

Make the cURL request to one of the routes you added the Approov authorizer:

```bash
curl -iX GET "https://${AWS_HTTP_API_ID}.execute-api.${AWS_REGION}.amazonaws.com" \
  --header "Approov-Token: $(approov token -type invalid -genExample ${API_DOMAIN})"
```
The above request should fail with an Unauthorized error. For example:

```json
HHTTP/2 403
content-type: application/json
apigw-requestid: BvrtujDgDoEEMqg=

{"message":"Forbidden"}
```

### Without the Required Approov Token Header

```bash
curl -iX GET "https://${AWS_HTTP_API_ID}.execute-api.${AWS_REGION}.amazonaws.com"
```

Output:

```json
HTTP/2 401
content-type: application/json
apigw-requestid: Bvr3chAYjoEEPgg=

{"message":"Unauthorized"}
```

## Troubleshooting

#### AWS CLI and Clock Time

The AWS CLI does some encryption on the data it sends in their requests, therefore if your computer clock it's not synchronized you may get errors saying that was a bad request and/or permissions issues.

For example, when using Windows 10 WSL2 with Ubuntu you may have Ubuntu in UTC+0 and the Windows 10 in UTC+1.

#### AWS Region

When your are asked to set the env var `AWS_REGION` you MUST use the same value configured at `~/.aws/config` otherwise it will cause permissions issues.

If you don't want to change your `~/.aws/config` file and still use a different AWS region then you need to add the `--region ___AWS_REGION_HERE___` to all AWS CLI commands you copy from this quickstart.

#### AWS Credentials

To use the AWS CLI its necessary that you have the Access Key ID and the Secret Access Key set in `~/aws/credentials` and they must be active in your IAM user.

#### Increase Logs Verbosity

If the cURL requests don't return the expected results then you need to check the CloudWatch logs for the lambda function and for the API. In case you cannot spot any cause in the logs you will need to increase the logs verbosity in the lambda function to `DEBUG`.

Execute the command:

```bash
aws lambda update-function-configuration \
    --function-name approov-token-lambda-authorizer \
    --environment '{"Variables": {"LAMBDA_LOG_LEVEL": "DEBUG"}}'
```

> **NOTE:** If you already have set env variables in your function you will need to add them again in the above command.


Now your lambda function will output more verbose logs and will make it easier to pinpoint the cause of the misbehavior.

For example:

```text
[INFO] 2021-07-13T11:37:34.066Z ff00e607-c4ec-40a5-8a5c-f3c150c76f78 Approov Token Verification: Invalid header padding
```

#### Approov CLI Authentication Expired

When you have enabled the `admin` role for the Approov CLI you have been prompted for a password on the first use, that will authenticate you for 1 hour, therefore if you are executing the cURL requests outside this 1 hour window then the authentication has expired.

Run any Approov CLI command to be prompted for the password again, for example:

```bash
approov token -genExample ${API_DOMAIN}
```

[TOC](#toc-table-of-contents)
