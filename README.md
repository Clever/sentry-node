## Sentry-node
**Node v0.10 compatible**

[![Build Status](https://travis-ci.org/Clever/sentry-node.png?branch=master)](https://travis-ci.org/Clever/sentry-node)

A simple Node wrapper around the [Sentry](http://getsentry.com/) API.

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

You can initialize `sentry-node` by passing in a Sentry DSN:
```javascript
var sentry = new Sentry('<your Sentry DSN>');
```

Or you can set it as an environment variable:
```javascript
// if process.env.SENTRY_DSN is set to your Sentry DSN
var sentry = new Sentry();
```
Passing a DSN to `Sentry` will override a DSN detected from the `SENTRY_DSN` environment variable.

You can also pass in the individual parameters that make up the DSN as an object:
```javascript
var sentry = new Sentry({
  key: '<your sentry public key>',
  secret: '<your sentry secret key>',
  project_id: '<your sentry project id>'
});
```

**Note:** If `SENTRY_DSN` is not set in the environment or the DSN passed to `Sentry` is invalid, the client will be disabled. You will still be able to call its methods, but no data will be sent to Sentry. This can be useful behavior for testing and development environments, where you may not want to be logging errors to Sentry.

### Error
```javascript
sentry.error(err, logger, culprit, extra);
```

#### sample

```javascript
sentry.error(
  new Error("The error method expected an Error instance as first argument."),
  '/sentry-node.coffee',
  "Bad arguments to sentry-node:error method",
  {
    note: "to test sentry-node error method", 
    version: "0.1.0"
  }
);
```
This image is out of date!
![image](http://i.imgur.com/xEHX8P3.png)

#### arguments

* **err:** the error object to log, must be an instance of `Error`, `err.message` will be used for the smaller text that appears right under `culprit`
* **logger:** the name of the logger which detected the error
* **culprit:** a string that specifies which function caused the error. If this is not known, should be `null`. If included, it the big text at the top of the sentry error.
* **extra:** (optional) an object that gives more context about the error, it will be augmented with a field `stacktrace` containing the value of `err.stack`

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

* **message:** text will be used for both the big text that appears at the top and the smaller text appears right under it
* **logger:** the name of the logger which created the message
* **extra:** (optional) an object that gives more context about the message

## Events

The Sentry client emits two events that you can listen to:

- `'logged'`: emitted when an error or message is successfully logged to Sentry
- `'error'`: emitted when an error occurs within the Sentry client and an error or message fails to be logged to Sentry
- `'warning'`: emitted when the logger parameter is not passed as a string.

```javascript
sentry.on('logged', function(){
  console.log('Yay, it worked!');
});
sentry.on('error', function(e){
  console.log('oh well, Sentry is broke.');
  console.log(e);
})
```

## Best Practices

The Sentry client expects an instance of `Error` - if it is given some other object, it will still send the error to Sentry, but much of the error content will be lost. This behavior is intended to align with the node.js best practice of always using `Error` instances. This means you should always take care to construct an `Error` object with an appropriate message before logging it to Sentry (really, you should always be using `Error` objects to represent error data throughout your codebase).

You should always give as much context as possible with your errors. Make liberal use of the `extra` parameter to send more information that may help someone (most likely your future self) diagnose the cause of the error.

If you attach other fields with important data to the `Error` instance, they will not show up in Sentry automatically. You should make sure to include those fields on the `extra` object.

Sentry asks for three main fields:
* `message`: what was the exception? Always the message from the passed in error.
* `logger`: what piece of code generated the message to Sentry? Usually just whatever application actually holds the Sentry client.
