# updown.io external monitoring service + status page

It is used as a check target to make sure all daemons are issuing requests, if any of the daemons isn't issuing requests any more it sends an email notification and changes the status of the component in the status page

It also monitors sidekiq processes with a periodic worker sending queue size.

Run server and console locally (with mailcatcher):
```sh
STAYTUS_SMTP_HOSTNAME=localhost STAYTUS_SMTP_PORT=1025 rails s
bin/rails c
```

Run specs:
```sh
rake
```

Deploy on Railway:
```sh
railway up
```

PG database dump
```sh
# Get Railway database credentials
railway variables | fgrep DATABASE_URL
# Dump from production
pg_dump postgresql://xxxx/railway -Ft > ./updown-status.dump
# restore database dump to dev
pg_restore --clean --no-owner -d staytus_dev updown-status.dump
# restore database dump to railway
pg_restore --clean --no-owner postgresql://xxxx/railway updown-status.dump
```

Fake monitoring requests:
```sh
curl -iH 'X-Forwarded-For: 91.121.222.175' localhost:8787/ping
curl -iH 'X-Forwarded-For: 91.121.222.175' -d 'queues[default]=5000&queues[mailers]=0&env=production' localhost:8787/sidekiq
```

