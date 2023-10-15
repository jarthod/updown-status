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

Deploy on Render:
```sh
git push
```

Database dump
```sh
# Import Render production DB in dev (invert to push DB to prod)
scp -s srv-cklr2o2v7m0s73al2020@ssh.frankfurt.render.com:/var/data/staytus_prod.sqlite3 db/staytus_dev.sqlite3
```

Fake monitoring requests:
```sh
curl -iH 'X-Forwarded-For: 91.121.222.175' localhost:8787/ping
curl -iH 'X-Forwarded-For: 91.121.222.175' -d 'queues[default]=5000&queues[mailers]=0&env=production' localhost:8787/sidekiq
```

