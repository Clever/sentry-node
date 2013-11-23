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

###register
```
Sentry = require 'sentry-node'

sentry = new Sentry({key: ..., secret: ..., project_id: ...})
```

Or you can save credentials in a separate file and import it when necessary.

###error
```
sentry.error(err, message, logger, extra)
```

###message
```
sentry.message(message, logger, extra)
```