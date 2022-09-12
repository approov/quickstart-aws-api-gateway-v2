# Approov QuickStart - AWS API Gateway

[Approov](https://approov.io) is an API security solution used to verify that requests received by your API services originate from trusted versions of your mobile apps.

This repo implements the Approov API request verification for the [AWS API Gateway](https://aws.amazon.com/api-gateway/), which performs the verification check on the Approov Token before allowing valid traffic to reach the API endpoint.

![Approov Authorizer diagram for the AWS API Gateway](/docs/img/approov-aws-api-gateway-authoriser.png)

If you are looking for another Approov integration you can check our list of [quickstarts](https://approov.io/docs/latest/approov-integration-examples/backend-api/), and if you don't find what you are looking for, then please let us know [here](https://approov.io/contact).



## Approov Integration Quickstart

The quickstart assumes that you already have an AWS API Gateway running, and that you are familiar with the options for applying changes. If you are not familiar with the AWS API Gateway then you may want to follow the step by step [AWS API Gateway Example](/docs/AWS_API_GATEWAY_EXAMPLE.md) instead.

The quickstart was tested with the following Operating Systems:

* Ubuntu 20.04
* MacOS Big Sur
* Windows 10 WSL2 - Ubuntu 20.04

If you find yourself lost or blocked in some part of the quickstart, then you can check the [detailed quickstart](docs/APPROOV_TOKEN_QUICKSTART.md).

To complete the quickstart you need to have an existing [HTTP API](https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-develop.html#http-api-examples.cli.quick-create) created in the AWS API Gateway, and also have the [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html) and [Approov CLI](https://approov.io/docs/latest/approov-installation/#approov-tool) installed.

To make it easier to run all the CLI commands we need to set some environment variables.

On Linux and MAC:

```bash
# AWS_DEFAULT_REGION=eu-west-2
export AWS_DEFAULT_REGION=___YOUR_AWS_DEFAULT_REGION_HERE___

# AWS_ACCOUNT_ID=1234567890
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# AWS_HTTP_API_ID=kbjza06bsd
export AWS_HTTP_API_ID=___YOUR_HTTP_API_ID_HERE___

# API_DOMAIN=your.api.domain.com
export API_DOMAIN=___YOUR_HTTP_API_DOMAIN_HERE___

# DOCKER_IMAGE_REGISTRY=1234567890.dkr.ecr.eu-west-2.amazonaws.com
export DOCKER_IMAGE_REGISTRY=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com

# DOCKER_IMAGE_NAME=1234567890.dkr.ecr.eu-west-2.amazonaws.com/approov-token-lambda-authorizer:13July2021_16h18m52s
export DOCKER_IMAGE_NAME=${DOCKER_IMAGE_REGISTRY}/approov-token-lambda-authorizer:$(date +%d%B%Y_%Hh%Mm%Ss)
```

First, enable your Approov `admin` role with:

```bash
eval `approov role admin`
````

For the Windows powershell:

```bash
set APPROOV_ROLE=admin:___YOUR_APPROOV_ACCOUNT_NAME_HERE___
````

Next, register the API domain for which Approov will issues tokens:

```bash
approov api -add ${API_DOMAIN}
```

Now, create an IAM role:

```bash
aws iam create-role \
    --role-name approov-lambda-execution-role \
    --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":["lambda.amazonaws.com"]},"Action":"sts:AssumeRole"}]}'
```

Next, attach a policy to the IAM role:

```bash
aws iam attach-role-policy \
    --role-name approov-lambda-execution-role \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
```

Now, to set the Approov secret in the AWS Secrets Manager execute:

```bash
aws secretsmanager create-secret \
    --name APPROOV_BASE64_SECRET \
    --description "The base64 encoded secret retrieved with the Approov CLI." \
    --secret-string "$(approov secret -plain -get base64)"
```

Next, export the `ARN` from the above command output with:

```bash
export APPROOV_BASE64_SECRET_AWS_ARN=___YOUR_AWS_ARN_HERE___
```

Now, set the permissions that will allow to access the secret from the lambda function:

```bash
aws secretsmanager put-resource-policy \
    --secret-id APPROOV_BASE64_SECRET \
    --resource-policy "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"AWS\":[\"arn:aws:iam::${AWS_ACCOUNT_ID}:role/approov-lambda-execution-role\"]},\"Action\":\"secretsmanager:GetSecretValue\",\"Resource\":\"${APPROOV_BASE64_SECRET_AWS_ARN}\"}]}"
```

Next, login to the AWS ECR repository:

```bash
aws ecr get-login-password | sudo docker login ${DOCKER_IMAGE_REGISTRY} --username AWS --password-stdin
```
> **NOTE:** The use of `sudo` after a pipe requires that you already have an active `sudo` session, because you will not see the prompt for the `sudo` password and the command will fail.

Now, create the AWS ECR repository:

```bash
aws ecr create-repository \
    --repository-name approov-token-lambda-authorizer \
    --image-scanning-configuration scanOnPush=true \
    --image-tag-mutability IMMUTABLE
```

Next, clone this repo in order to be able to build the docker image with the lambda function:

```bash
git clone https://github.com/approov/quickstart-aws-api-gateway-v2.git
cd quickstart-aws-api-gateway-v2
```

Now, build the docker image:

```bash
sudo docker build --tag ${DOCKER_IMAGE_NAME} ./lambda/python # or nodejs
```

Next, start the docker image to run a smoke test on it:

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

Now, run the smoke test:

```bash
curl -X POST "http://localhost:9000/2015-03-31/functions/function/invocations" -d "{\"headers\": {\"approov-token\": \"$(approov token -type valid -genExample ${API_DOMAIN})\"}}"
```

Next, create the Approov lambda function:

```bash
aws lambda create-function \
    --function-name approov-token-lambda-authorizer \
    --package-type Image \
    --code ImageUri=${DOCKER_IMAGE_NAME} \
    --role arn:aws:iam::${AWS_ACCOUNT_ID}:role/approov-lambda-execution-role
```

Now, create the the Approov lambda authorizer:

```bash
aws apigatewayv2 create-authorizer \
    --api-id ${AWS_HTTP_API_ID} \
    --authorizer-type REQUEST \
    --identity-source '$request.header.Approov-Token' \
    --name approov-token-api-authorizer \
    --authorizer-uri "arn:aws:apigateway:${AWS_DEFAULT_REGION}:lambda:path/2015-03-31/functions/arn:aws:lambda:${AWS_DEFAULT_REGION}:${AWS_ACCOUNT_ID}:function:approov-token-lambda-authorizer/invocations" \
    --authorizer-payload-format-version '2.0' \
    --enable-simple-responses
```

Next, export the authorizer ID to the environment:

```bash
export AWS_AUTHORIZER_ID=___YOUR_AUTHORIZER_ID_HERE___
```

Now, add the lambda permissions to the authorizer:

```bash
aws lambda add-permission \
    --function-name approov-token-lambda-authorizer \
    --statement-id api-gateway-quickstart-lambda-permissions-01 \
    --action lambda:InvokeFunction \
    --principal apigateway.amazonaws.com \
    --source-arn "arn:aws:execute-api:${AWS_DEFAULT_REGION}:${AWS_ACCOUNT_ID}:${AWS_HTTP_API_ID}/authorizers/${AWS_AUTHORIZER_ID}"
```

Finally, for each route you want to protect with Approov execute:

```bash
aws apigatewayv2 update-route \
    --api-id ${AWS_HTTP_API_ID} \
    --authorizer-id ${AWS_AUTHORIZER_ID} \
    --authorization-type CUSTOM \
    --route-id ___YOUR_ROUTE_ID_HERE___
```

Not enough details in the bare bones quickstart? No worries, check the [detailed quickstart](docs/APPROOV_TOKEN_QUICKSTART.md) that contain a more comprehensive set of instructions, including how to test the Approov integration.


## More Information

* [Approov Overview](OVERVIEW.md)
* [Detailed Quickstart](docs/APPROOV_TOKEN_QUICKSTART.md)
* [Step by Step Example](docs/AWS_API_GATEWAY_EXAMPLE.md)
* [Testing](docs/APPROOV_TOKEN_QUICKSTART.md#test-your-approov-integration)


## Issues

If you find any issue while following our instructions then just report it [here](https://github.com/approov/quickstart-aws-api-gateway-v2/issues), with the steps to reproduce it, and we will sort it out and/or guide you to the correct path.


## Useful Links

If you wish to explore the Approov solution in more depth, then why not try one of the following links as a jumping off point:

* [Approov Free Trial](https://approov.io/signup)(no credit card needed)
* [Approov Get Started](https://approov.io/product/demo)
* [Approov QuickStarts](https://approov.io/docs/latest/approov-integration-examples/)
* [Approov Docs](https://approov.io/docs)
* [Approov Blog](https://approov.io/blog/)
* [Approov Resources](https://approov.io/resource/)
* [Approov Customer Stories](https://approov.io/customer)
* [Approov Support](https://approov.io/contact)
* [About Us](https://approov.io/company)
* [Contact Us](https://approov.io/contact)
