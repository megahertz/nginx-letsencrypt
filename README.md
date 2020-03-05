# nginx-letsencrypt

[![](https://images.microbadger.com/badges/image/megahertz/nginx-letsencrypt.svg)](https://microbadger.com/images/megahertz/nginx-letsencrypt "microbadger.com")

Nginx with auto-renewal Let’s Encrypt script in a single Docker container

Despite the fact that having multiple processes is not true Docker way,
sometimes it's very convenient to have just one small container which needs
no orchestration infrastructure.

This Dockerfile contains nginx and a simple script which automatically
issues an SSL certificate from Let’s Encrypt. It also contains cron task
which automatically checks for certificate renewal.

## Using in Dockerfile

**Dockerfile**
```dockerfile
FROM megahertz/nginx-letsencrypt:1.0.2

ENV LE_DOMAINS='mydomain.com'

ADD mydomain.conf /etc/nginx/conf.d/mydomain.conf
ADD www /var/www/mydomain.com
```

**mydomain.conf**
```
server {
    listen 443 ssl http2;
    server_name mydomain.com;

    location = / {
       root /var/www/mydomain.com;
       index index.html;
       try_files $uri $uri/ =404;
    }
}
```

That's it. Just build and run your container:

```sh
docker build . -t mydomain.com
docker run -p 80:80 -p 443:443 mydomain.com
```

## Saving certificates

If you would like to prevent loosing certificates when the container removed,
set `/cert/data` path as a volume before first run:

```sh
docker run -p 80:80 -p 443:443 -v "./data:/cert/data" mydomain.com
```

## Variables

There are only three environment variables:

#### `LE_DOMAINS`

Which domain to use

#### `LE_EMAIL`

When issuing a certificate, set email address for Let’s Encrypt.

#### `LE_DEBUG`

When testing, it's helpful to set this value to '1'. When enabled, it shows
detailed log, executes certificate check each minute and uses Let’s Encrypt
staging API. With the staging API you'll receive test certificate instead of
real, that prevents you from
[exceeding issuing limit](https://letsencrypt.org/docs/rate-limits/).
