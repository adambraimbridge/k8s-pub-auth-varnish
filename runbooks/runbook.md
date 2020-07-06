# UPP - Publish varnish

Publish varnish is the main entry point in the publish cluster. It performs authentication when needed and routes traffic to the cluster's applications.

## Code

k8s-pub-auth-varnish

## Primary URL

<https://upp-prod-publish-glb.upp.ft.com/>

## Service Tier

Platinum

## Lifecycle Stage

Production

## Delivered By

content

## Supported By

content

## Known About By

- mihail.mihaylov
- hristo.georgiev
- elitsa.pavlova
- kalin.arsov
- elina.kaneva
- georgi.ivanov

## Host Platform

AWS

## Architecture

Varnish is the entry point for Publishing clusters. Service is having few main functions - authentification/reverse proxy/cache/load-balancing for services in the Publishing clusters. This varnish instance is performing static routing primary, but for dynamic routing is referred to Path Routing Varnish service. In this service is also located DNS registration job for main URL of the cluster. After authentification this service will route the request to the needed service.

## Contains Personal Data

No

## Contains Sensitive Data

No

## Failover Architecture Type

ActivePassive

## Failover Process Type

FullyAutomated

## Failback Process Type

FullyAutomated

## Failover Details

The service is deployed in all clusters. The failover guide for the clusters is located here: <https://github.com/Financial-Times/upp-docs/tree/master/failover-guides/publishing-cluster>

## Data Recovery Process Type

FullyAutomated

## Data Recovery Details

Data for requests is stored in Splunk. Authentification secrets are encrypted and stored in Publishing clusters and in emergency LastPass note "UPP - k8s Basic Auth".

## Release Process Type

FullyAutomated

## Rollback Process Type

Manual

## Release Details

The deployment is automated.

## Key Management Process Type

None

## Key Management Details

There are no keys for rotation.

## Monitoring

- https://upp-prod-publish-us.upp.ft.com/__health
- https://upp-prod-publish-eu.upp.ft.com/__health

## First Line Troubleshooting

https://github.com/Financial-Times/upp-docs/tree/master/guides/ops/first-line-troubleshooting

## Second Line Troubleshooting

Please refer to the https://github.com/Financial-Times/k8s-pub-auth-varnish/blob/master/README.md
