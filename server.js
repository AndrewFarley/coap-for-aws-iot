#!/usr/bin/env node

const coap    = require('coap')
const server  = coap.createServer()
const sqs     = require('sqs');
const queue = sqs( {access: process.env.AWS_ACCESS_KEY_ID, 'secret': process.env.AWS_SECRET_ACCESS_KEY, region: process.env.AWS_DEFAULT_REGION} )

server.on('request', function(req, res) {

  try {
    if (req.url.startsWith("/.well-known/core")) {
      console.log("requesting well-known core, ignoring...")
      res.end('</no-published-endpoints-available>;if="inv"')
      return
    }
    
    // console.log("Pushing to SQS queue:")
    payload = {timestamp: Math.floor(new Date() / 1000), ip: req.rsinfo.address, path: req.url, method: req.method, payload: req.payload.toString('utf8')}
    console.log(JSON.stringify(payload))
    try {
      queue.push(process.env.SQS_QUEUE_NAME, payload, function () {
        res.end('RECEIVED OK')
      });
    } catch (err) {
      console.log("Error while saving to queue: " + err)
      res.end('FAILURE')
    }

  } catch (err) {
    console.log("Exception occurred: " + err)
    res.end('Unknown/internal exception occurred')
  }
})

server.listen(function() {
  console.log('server started')
})

