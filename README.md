## Sentry-node
**Node v0.10 compatible**

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


### Error
```javascript
sentry.error(err, message, logger, extra);
```

#### arguments

![image](http://i.imgur.com/xEHX8P3.png)

* **err:** must be an instance of `Error`, `err.message` will be used for the smaller text that appears right under `culprit`
* **message:** `culprit`, big text that appears at the top
* **logger:** the name of the logger which created the record, should be the error logger/handler in your code
* **extra:** (optional) an object gives more context about the error in addition to `err.stack`

```javascript
sentry.error(err, "Unknown Error", 'apps/api', {note: "some random guess why this would happen...", version: "0.1.0"});
```


### Message
```javascript
sentry.message(message, logger, extra);
```

#### arguments

![image](http://i.imgur.com/kUMkhX2.png)

* **message:** text will be used for both the big text appears at the top and the smaller text appears right under it
* **logger:** the name of the logger which created the record
* **extra:** (optional) an object gives more context about the message

```javascript
sentry.message("Completed job: <description you choose>", "apps/worker");
```