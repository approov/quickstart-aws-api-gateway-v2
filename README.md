# Approov QuickStart - AWS API Gateway

[Approov](https://approov.io) is an API security solution used to verify that requests received by your API services originate from trusted versions of your mobile apps.

This repo implements the Approov API request verification for the [AWS API Gateway](https://aws.amazon.com/api-gateway/), which performs the verification check on the Approov Token before allowing valid traffic to reach the API endpoint.

![Approov Authorizer diagram for the AWS API Gateway](/docs/img/approov-aws-api-gateway-authoriser.png)

If you are looking for another Approov integration you can check our list of [quickstarts](https://approov.io/docs/latest/approov-integration-examples/backend-api/), and if you don't find what you are looking for, then please let us know [here](https://approov.io/contact).


## TOC - Table of Contents

* [Why?](#why)
* [How it Works?](#how-it-works)
* [Quickstart](#approov-integration-quickstart)
* [Useful Links](#useful-links)


## Why?

You can learn more about Approov, the motives for adopting it, and more detail on how it works by following this [link](https://approov.io/product). In brief, Approov:

* Ensures that accesses to your API come from official versions of your apps; it blocks accesses from republished, modified, or tampered versions
* Protects the sensitive data behind your API; it prevents direct API abuse from bots or scripts scraping data and other malicious activity
* Secures the communication channel between your app and your API with [Approov Dynamic Certificate Pinning](https://approov.io/docs/latest/approov-usage-documentation/#approov-dynamic-pinning). This has all the benefits of traditional pinning but without the drawbacks
* Removes the need for an API key in the mobile app
* Provides DoS protection against targeted attacks that aim to exhaust the API server resources to prevent real users from reaching the service or to at least degrade the user experience.

[TOC](#toc-table-of-contents)


## How it works?

This is a brief overview of how the Approov cloud service and the AWS API Gateway fit together from a backend perspective. For a complete overview of how the mobile app and backend fit together with the Approov cloud service and the Approov SDK we recommend that you read the [Approov overview](https://approov.io/product) page on our website.

### Approov Cloud Service

The Approov cloud service attests that a device is running a legitimate and tamper-free version of your mobile app.

* If the integrity check passes then a valid token is returned to the mobile app
* If the integrity check fails then a legitimate looking token will be returned

In either case, the app, unaware of the token's validity, adds it to every request it makes to Approov protected API(s).

### AWS API Gateway

This quick start shows you how to setup AWS API Gateway to ensure that the token supplied in the `Approov-Token` header is present and valid. The validation is done by using a shared secret known only to the Approov cloud service and your AWS API Gateway deployment.

The request is handled such that:

* If the Approov Token is valid, the request is allowed to reach the API endpoint
* If the Approov Token is invalid, an HTTP 403 Forbidden response is returned
* If the Approov Token is missing, an HTTP 401 Unauthorized response is returned

[TOC](#toc-table-of-contents)


## Approov Integration Quickstart

The quickstart for the Approov integration with the AWS API Gateway gets you up and running with basic Approov token checking:

* [Approov token check quickstart](/docs/APPROOV_TOKEN_QUICKSTART.md)

Please bear in mind that the quickstart assumes that you already have an AWS API Gateway running, and that you are familiar with the options for applying changes. If you are not familiar with the AWS API Gateway then you may want to follow the step by step [AWS API Gateway Example](/docs/AWS_API_GATEWAY_EXAMPLE.md) instead. This takes you though all the steps to get a new deployment with Approov protection from scratch.

If you need further help adding Approov to your AWS API Gateway deployment then please contact us [here](https://approov.io/contact).


## Useful Links

If you wish to explore the Approov solution in more depth, then why not try one of the following links as a jumping off point:

* [Approov Free Trial](https://approov.io/signup) (no credit card needed)
* [Approov QuickStarts](https://approov.io/docs/latest/approov-integration-examples/)
* [Approov Live Demo](https://approov.io/product/demo)
* [Approov Docs](https://approov.io/docs)
* [Approov Blog](https://blog.approov.io)
* [Approov Resources](https://approov.io/resource/)
* [Approov Customer Stories](https://approov.io/customer)
* [Approov Support](https://approov.zendesk.com/hc/en-gb/requests/new)
* [About Us](https://approov.io/company)
* [Contact Us](https://approov.io/contact)

[TOC](#toc-table-of-contents)
