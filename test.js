#!/usr/bin/env node

const coap = require('coap')
const req  = coap.request('coap://PUT_TERRAFORM_OUTPUT_PUBLIC_IP_HERE/x-node/xxxx-ssss-1111-2222')

function getRandomInt(min, max) {
  min = Math.ceil(min);
  max = Math.floor(max);
  return Math.floor(Math.random() * (max - min)) + min; //The maximum is exclusive and the minimum is inclusive
}

var payload = {
   "metric1": getRandomInt(5,25),
   "metric2": getRandomInt(5,25)
}

req.write(JSON.stringify(payload));

console.log('Request: ')
console.log(payload)

req.on('response', function(res) {
  res.pipe(process.stdout)
})

req.on('end', function() {
  console.log("")
  process.exit(0)
})

req.end()