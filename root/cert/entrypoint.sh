#!/bin/sh

if [ -n "${LE_DEBUG}" ]; then
  set -ex
else
  set -e
fi

get_domain_args() {
  if [ -z "${LE_DOMAINS}" ]; then
    exception 'LE_DOMAINS environment variable is not set'
  fi

  local domains="${LE_DOMAINS//[,]/-d }"
  echo "-d ${domains}"
}

exception() {
  local text="$@"
  echo -e "\033[0;31m${text}\033[0m" 1>&2
  exit 1
}

install_acme() {
  cd /usr/share/acme.sh

  local args; args="$(get_domain_args)"

  if [ -n "${LE_DEBUG}" ]; then
    args="${args} --test"
  fi

  if [ -n "${LE_EMAIL}" ]; then
    args="${args} --accountemail "${LE_EMAIL}""
  fi

  acme.sh --install ${args} --home /cert/data/acme.sh

  nginx -c /cert/verify.conf
  acme.sh --issue --home /cert/data/acme.sh ${args} --webroot /cert/data/www
  killall -9 nginx

  mkdir -p /cert/data/issued
  acme.sh --install-cert ${args} --home /cert/data/acme.sh \
    --key-file /cert/data/issued/key.pem  \
    --fullchain-file /cert/data/issued/cert.pem \
    --reloadcmd 'test -e /var/run/nginx.pid && nginx -s reload || true'
}

run_cron() {
  if [ -z "${LE_DEBUG}" ]; then
    crond -b
    exit 0
  fi

  # Patch crontab to execute renewal each minute and show logs
  sed -i 's#[0-9]* [0-9]* \* \* \*#* * * * *#; s# > /dev/null##' \
    /etc/crontabs/root

  crond -f -l 0 &
}

# Run acme.sh install if there is no certificate
if [ ! -f /cert/data/issued/cert.pem ]; then
  install_acme
fi;

# Check whether to update cert on start
acme.sh --cron --home /cert/data/acme.sh

run_cron

"$@"
