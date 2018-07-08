// This is a handful of dynamic helper variables we pull from Serverless.yml
var AWS = require('aws-sdk');
AWS.config.update({region: 'eu-west-1'});
var ec2 = new AWS.EC2()
var os = require("os")
var path = require("path");

// This gets us our AWS Account ID into serverless.yml
module.exports.aws_account_id = function() {
  test = new Promise((resolve, reject) => {
    // Try to get our "singular" account from a default security group, assuming there is one...
    params = {
      GroupNames: [
        'Default'
      ]
    };

    ec2.describeSecurityGroups(params, function(err, data) {
      if (err) {
        // TODO: Fallback to some alternate mechanism when no default security group...?  Should always work tho...
        console.log(err, err.stack);
        reject(err)
       }
      else return resolve(data.SecurityGroups[0].OwnerId);
    });
  });
  return test
}

// This gets us our current folder name, used to get the name of a stack dynamically (for multi-sub-stacking)
module.exports.current_folder_name = function() {
   var test = process.cwd();
   var ret = test.split("/").reduce((p,c,i,arr) => {if(i >= arr.length - 1){return (p?("\\"+p+"\\"):"")+c}});
   return Promise.resolve(ret);
}

// This gets the Python requirements configuration
module.exports.get_python_reqs_config = function() {
  if (os.platform() != 'linux')
    // return Promise.resolve({invalidateCaches: false, dockerizePip: true});
    return Promise.resolve({invalidateCaches: false, useStaticCache: true, useDownloadCache: true, dockerizePip: true, dockerImage: "andrewfarley/serverless-personal-building-with-mysql"});
  return Promise.resolve({invalidateCaches: false});
}
