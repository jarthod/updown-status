# updown.io external monitoring service + status page

It is used as a check target to make sure all daemons are issuing requests, if any of the daemons isn't issuing requests any more it sends an email notification and changes the status of the component in the status page

It also monitors sidekiq processes with a periodic worker sending queue size.

Run server and console locally:
```sh
bin/rails s
bin/rails c
```

Run specs:
```sh
rake
```

Import database from heroku (production) to dev
```sh
dropdb staytus_dev
heroku pg:pull DATABASE staytus_dev
```

Dump database from fly.io
```sh
fly proxy 15432:5432 --app updown-status-db
/usr/lib/postgresql/14/bin/pg_dump postgres://updown_status:xxxxxxxx@localhost:15432/updown_status -Ft > ./updown-status.dump
```

Restore database to railway.app
```sh
/usr/lib/postgresql/14/bin/pg_restore -U postgres -h containers-us-west-33.railway.app -p 7540 -W -F t -d railway updown-status.dump
```

Fake monitoring requests:
```sh
curl -iH 'X-Forwarded-For: 91.121.222.175' localhost:8787/ping
curl -iH 'X-Forwarded-For: 91.121.222.175' -d 'queues[default]=5000&queues[mailers]=0&env=production' localhost:8787/sidekiq
```

# Railway

Deploy:

```sh
railway up
```