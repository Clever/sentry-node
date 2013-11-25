##Sentry-node
**Node v0.10 compatible**

A simple Node wrapper around [Sentry](http://getsentry.com/) API.


##Installation
```
$ npm install sentry-node
```

##Testing
```
$ npm test
```


##Usage

###register client
```coffeescript
Sentry = require 'sentry-node'

sentry = new Sentry({key: ..., secret: ..., project_id: ...})
```

Or you can save credentials in a separate file and import it when necessary.

###error
```coffeescript
sentry.error err, message, logger, extra
```

####arguments

* **err:** an Error object in JS, `err.message` would be the smaller text that appears right under `culprit`
* **message:** `culprit`, big text that appears at the top
* **logger:** the name of the logger which created the record, should be the error logger/handler in your code
* **extra:** (optional )give more context about the error in addition to `err.stack`

```coffeescript
log_error = (err) ->
	console.log err
	sentry.error err, "Unknown Error", 'apps/api', "some random guess why this would happen..."
```


###message
```coffeescript
sentry.message message, logger, extra
```

####arguments

* **message:** text appears in the record
* **logger:** the name of the logger which created the record
* **extra:** (optional) context

```coffeescript
sentry.message "Completed job: #{description}", "apps/worker"
```