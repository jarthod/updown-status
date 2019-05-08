Import database from heroku (production) to dev

    dropdb staytus_dev
    heroku pg:pull DATABASE staytus_dev

Dev console and server

    bin/rails s -e development
    bin/rails c -e development
