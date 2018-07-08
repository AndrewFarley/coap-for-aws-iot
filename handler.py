#!/usr/bin/env python3
import time
import boto3
import json
import sys
import traceback
import os
import subprocess
from pprint import pprint

aws_region = 'eu-west-1'

sqs     = boto3.resource( 'sqs', region_name=aws_region )
queue   = sqs.Queue('https://sqs.eu-west-1.amazonaws.com/594560747451/coap-dev')
iot     = boto3.client('iot', region_name=aws_region)
iotdata = boto3.client('iot-data', region_name=aws_region)

def findOrCreateThingType(thingTypeName):
    try:
        iot.create_thing_type(
            thingTypeName=thingTypeName,
            thingTypeProperties={
                'thingTypeDescription': thingTypeName,
                'searchableAttributes': [
                    'CreatedByCoAPForAWSIoTByAndrewFarleyOnGitsHub',
                ]
            }
        )
    except Exception as e:
        if "ResourceAlreadyExistsException" in "{}".format(e):
            pass
            # print("It's ok already exists")
        else:
            print("ERROR: Some other error occurred")
            print(e)
            raise

def findOrCreateThing(thingTypeName, thingName):

    # Then create the thing
    try:
        iot.create_thing(
            thingName=thingName,
            thingTypeName=thingTypeName,
            attributePayload={
                'attributes': {
                    'FirstSeen': "NOW"
                },
                'merge': False
            }
        )
    except Exception as e:
        if "ResourceAlreadyExistsException" in "{}".format(e):
            pass
            # print("It's ok already exists")
        else:
            print("ERROR: Some other error occurred")
            print(e)
            raise

def updateThingShadow(thingName, thingShadow):
    # Update this device shadow
    response = iotdata.update_thing_shadow(
        thingName=thingName,
        payload=json.dumps(thingShadow)
    )


def updateThing(thingTypeName, thingName, thingShadow):
    # First create the thing type
    findOrCreateThingType(thingTypeName)
    # Second, create the thing
    findOrCreateThing(thingTypeName, thingName)
    # Third, update the thing shadow
    updateThingShadow(thingName, thingShadow)


def merge_dicts(*dict_args):
    """
    Given any number of dicts, shallow copy and merge into a new dict,
    precedence goes to key value pairs in latter dicts.
    """
    result = {}
    for dictionary in dict_args:
        if isinstance(dictionary, dict):
            result.update(dictionary)
    return result

def is_number(s):
    try:
        float(s)
        return True
    except ValueError:
        return False


from urllib.parse import urlparse

def lambda_handler(event, context):
    print("got event")
    print(event)
    print("Listening for messages from SQS queue...")
    loops = 0
    maxloops = 10
    while True:
        loops = loops + 1
        if loops >= maxloops:
            break
        try:
            messages = queue.receive_messages(WaitTimeSeconds=1, MaxNumberOfMessages=10, VisibilityTimeout=1)
            if len(messages) == 0:
                break
            for message in messages:
                print("Message received: {0}".format(message.body))
                try:
                    contents = json.loads(message.body)
                    o = urlparse(contents['path'])
                    path_parts = list(filter(None, o.path.split('/')))
                    print(path_parts)
                    
                    # Validate format...
                    if len(path_parts) != 2:
                        print("Wrong format, move to DLQ queue?  For now delete")
                        message.delete()
                        continue
                    
                    # TODO: Check validity ?  Custom CRC/Hash?
                    
                    # Parse our JSON Payload to pull out metrics
                    payload = json.loads(contents['payload'])

                    # Create and/or update our thing
                    updateThing(path_parts[0], path_parts[1], {'state': {
                        "reported" : merge_dicts(payload, {"online": "true", "uuid": path_parts[1], "type": path_parts[0]})
                    }})
                    
                    # Immediately delete incase something fails below...
                    message.delete()
                except Exception as e:
                    print("Caught exception")
                    exc_info = sys.exc_info()
                    traceback.print_exception(*exc_info)

                    # TODO: Move message to DLQ for manual in inspection...?
                    message.delete()

                # Now slack our results
                # pprint(contents)
                # helpers.slackDoorActions("<@{}|{}>".format(contents['user_id'],contents['user_name']),state, "via Slack")
        except Exception as e:
            print("Got exception: {}".format(e))
            pass


# response = iotdata.get_thing_shadow(
#     thingName=thingName
# )
# 
# streamingBody = response["payload"]
# jsonState = json.loads(streamingBody.read())
# pprint(jsonState)

if __name__ == "__main__":
    data = lambda_handler({}, "test")
    # data['body'] = json.loads(data['body'])
    # print( json.dumps(data, sort_keys=True, indent=4, separators=(',', ': ')) )
