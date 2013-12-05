## Sentry-node
**Node v0.10 compatible**

[![Build Status](https://travis-ci.org/Clever/sentry-node.png?branch=master)](https://travis-ci.org/Clever/sentry-node)

A simple Node wrapper around [Sentry](http://getsentry.com/) API.


## Installation
```
$ npm install sentry-node
```

## Testing
```
$ npm test
```


## Usage

### Creating the Client

```javascript
var Sentry = require('sentry-node');
```
You can intialize `sentry-node` by passing in a Sentry DSN:
```javascript
var sentry = new Sentry('<your Sentry DSN>');
```
Or you can set it as an `process.env` variable:
```javascript
var sentry = new Sentry();
```
You can also pass in the config parameters as an object:
```javascript
var sentry = new Sentry({
  key: '<your sentry public key>',
  secret: '<your sentry secret key>',
  project_id: '<your sentry project id>'
});
```

**Note:**

- If `SENTRY_DSN` is not set or argument to `Sentry` is invalid, client will be disabled.
- Argument to `Sentry` will update client settings even if `SENTRY_DSN` is set.


### Error
```javascript
sentry.error(err, message, logger, extra);
```

#### sample

```javascript
sentry.error(
  new Error("The error method expected an Error instance as first argument."),
  "Bad arguments to sentry-node:error method",
  '/sentry-node.coffee',
  {
    note: "to test sentry-node error method", 
    version: "0.1.0"
  }
);
```

![image](http://i.imgur.com/xEHX8P3.png)

#### arguments

* **err:** must be an instance of `Error`, `err.message` will be used for the smaller text that appears right under `culprit`
* **message:** `culprit`, big text that appears at the top
* **logger:** the name of the logger which created the record, should be the error logger/handler in your code
* **extra:** (optional) an object gives more context about the error in addition to `err.stack`


### Message
```javascript
sentry.message(message, logger, extra);
```

#### sample

```javascript
sentry.message(
  "message",
  "/trial.coffee",
  {
    note: "to test sentry-node api",
    type: "message"
  }
);
```

![image](http://i.imgur.com/kUMkhX2.png)

#### arguments

* **message:** text will be used for both the big text appears at the top and the smaller text appears right under it
* **logger:** the name of the logger which created the record
* **extra:** (optional) an object gives more context about the message


## Events

Sentry Client emits two events, `logged` and `error` that you can listen to.

```javascript
client.on('logged', function(){
  console.log('Yay, it worked!');
});
client.on('error', function(e){
  console.log('oh well, Sentry is broke.');
  console.log(e);
})
client.message('Boom', 'logger');
```