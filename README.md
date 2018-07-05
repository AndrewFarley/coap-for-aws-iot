# CoAP for AWS IoT
From: [github.com/AndrewFarley/coap-for-aws-iot](https://github.com/AndrewFarley/coap-for-aws-iot)

_As of July 5, 2018 this is a work in progress.  Feel free to follow along if you're interested._

## Problem

Amazon doesn't support CoAP which is ideal for extremely low power and low bandwidth.

## Solution
AWS IoT offers some great features, a rule engine, super high scalability and availability, so we'll build a simple-to-deploy set of micro service(s) which can funnel CoAP data into AWS IoT via the following technologies.

## Author
[Farley Farley Farley](farley@neonsurge.com) - farley@neonsurge.com

## Purpose
Personal and professional interest in AWS, IoT and CoAP, plans to build this into a platform

## Footnotes / Problems / Fore-Thoughts
 * AWS Load Balancers do NOT do UDP, so load balancing this via traditional means on AWS is not possible.
 * I researched using AWS EKS / Fargate or such technologies, since they mostly rely on the AWS Load Balancers, I had to stay away from them unfortunately.  I could use Fargate without a Load Balancer, but I would not actually get a traditional static IP that I could guarantee wouldn't change.
 * For the absolute lowest-power utilization of a IoT device, I'd recommend not using DNS, instead just hardcoding IP addresses into their firmware.  Since we can get Static IPs from AWS, this is fairly simple, and this is the concept leverage in this example.
 * The current idea/concept/implementation isn't built for the "full" CoAP spec including Observing or two-way communication at the moment.  This will be for data ingestion via CoAP alone.  This concept could be expanded to include those patterns if desired, but would require expanding the reach and capabilities of the ingestion server, which I would like to avoid for now.

## Data & Technology Flow & Notes
1. Terraform code in this repo will spin up a SQS Queue, an Instance Role to push to this queue, and a CoAP Ingestor on a EC2 Instance.
    * This will be a dead-simple CoAP data ingestion platform, written in NodeJS and Docker.  Feel free to check it out [here](https://hub.docker.com/r/andrewfarley/coap-for-aws-iot/) or [here](https://github.com/AndrewFarley/coap-for-aws-iot).
    * This ingestor will do NO data validation in any way, it literally will stream input CoAP data directly into the SQS queue.  This does support the CoAP .well-known/core feature set at its basics but it will not advertise any valid endpoints, as it technically has none and infinite all at once in the way it is designed.
1. CoAP data ingested will need to conform to some pre-defined standard format.  For purposes of this example, we will use POST to a path which has the first path being the IoT device "type" and the second path being the IoT device unique ID / Mac address / UUID / etc, with the content body being a JSON blob.  In a real-world scenario, the JSON blob would probably be a highly-compressed binary format which you would have to unfold inside Lambda.
1. Now that we successfully ingested data from CoAP and saved/streamed to a highly scalable queued location (SQS) and we informed the user that we received it, we will need to process this data.  Lambda to the rescue!  The next part of this solution is [Serverless](https://serverless.com/) stack with Python that will run on a regular cron-like schedule (once every interval, say, 5 minutes) to check if there are any messages in the queue, and to process them if there are.
    * Inside this lambda, it will need to do a few things... 
    * First, look at the device type and if that isn't a current device type, to add it
    * Then, look if there is an IoT Device with that Unique ID, if not, create it
    * The finally, any properties from the data packet part will be pushed as metrics into the device.

## SCREENSHOTS / EXAMPLES / TUTORIAL HERE 
* TODO
* TODO
* TODO

## TODO / Security / High Availability / Performance
* Clean up the codebase, it's a mess... once things are working though
* Add diagrams, documentation, a walkthrough once things are finalized and flowing
* Limit the Terraform IAM Role for SQS to _only_ our SQS queue
* Modify the Ingestor to use the IAM Instance Role instead of passing credentials via user data.  The lame library [sqs](https://www.npmjs.com/package/sqs) only supports credentials.
* Implement a DLQ for the SQS queue incase things don't get processed
* Add CloudWatch alarms to alert us if messages are stuck in the queue
* By design, this is not inherently secure.  Anyone snooping on the wire could see this packet if they caught it in a packet trace and replicate it and poison the system with bad data.  You could very easily add a custom CRC into the data packet or onto the end of the URL that would CRC your algorithm against the data packet.  I would still NOT do this parsing in the data ingestion, I would let the data stream in as fast as humanly possible and validate/parse it later.  However, if you want to be able to give users (devs...?) feedback if their requests have the right CRC or not, then this CRC would need to be implemented in the ingestor.  This should be relatively simple to add, I will probably do this eventually if/when I roll this platform out to a client.
* For high availability, I recommend you deploy this stack with two instances instead of just one, with two static IP addresses.
* With more than one IP address, I recommend IoT device firmwares are programmed to round-robin between available IP addresses.  This will automatically provide some degree of high-availability and eventual delivery.
* For eventual consistency/delivery, I recommend clients "wait" for the UDP response for at least a second.  If they do not hear the "ACK" heartbeat back, on their following check in they should exponentially wait longer (up to a maximum) to ensure that data eventually gets to the backend.  Once a successful ACK is received, can reset back to 1 second.  This will help ensure the minimal battery usage.  An alternate model would be based on time since ACK received and a hard limit.  So, if a device is programmed to  check in once every hour, but it has a hard limit of 4 hours between verified checkins, then if it hasn't received ACKs in the first three hours, when it's over the hard limit it will leave the network connection open for a long period of time (eg: 10 seconds) to wait for the ACK.  If none is received, then on future requests will continue to leave the connection open this long for an ACK until it has proof the data is upstream, then it can reset back down to 1 second.
* In a future version, to support the two-way communication and Observer pattern that CoAP supports, and that AWS IoT via MQTT inherently support, the ingestor might be a "middleman" between AWS IoT and CoAP, either directly, or possibly through AWS Lambda to allow for advanced routing, rules, security, etc.
