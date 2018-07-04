# coap-for-aws-iot

This is a work in progress, and a proof of concept for a "potential" client of mine

Amazon doesn't support CoAP which is extremely low power, so we'll build a super-micro service which can funnel CoAP data into AWS IoT via the following technologies and flows...

This concept isn't build for the "full" CoAP spec including Observing or two-way communication at the moment.  Only for data ingestion.  This concept could be expanded to incldue those patterns if desired.

1. Ingest CoAP data with a simple Fargate EKS task (via Docker) into a SQS Queue
  1. This data must follow some standardized/normalized path and data structure.  For this PoC we will use JSON, but this could also be a simple binary construct
1. Have a serverless / lambda initiate whenever there is data in this queue, processing these records
  1. This serverless will initiate when there is items in the SQS queue, pull them out, create IoT object if they aren't a current object, and record their state/status

## THAT'S IT!  CoAP for AWS IoT

## Simple eh boys?  :)  Now lets see the magic...
