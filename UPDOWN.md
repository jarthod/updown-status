# updown.io external monitoring service + status page

It is used as a check target to make sure all daemons are issuing requests, if any of the daemons isn't issuing requests any more it sends an email notification and changes the status of the component in the status page

It also monitors sidekiq processes with a periodic worker sending queue size.

Run server and console locally:
```
bin/rails s
bin/rails c
```

Run specs:
```
rake
```

Import database from heroku (production) to dev
```
dropdb staytus_dev
heroku pg:pull DATABASE staytus_dev
```

Fake monitoring requests:
```
curl -iH 'X-Forwarded-For: 91.121.222.175' localhost:8787/ping
curl -iH 'X-Forwarded-For: 91.121.222.175' -d 'queues[default]=5000&queues[mailers]=0&env=production' localhost:8787/sidekiq
```