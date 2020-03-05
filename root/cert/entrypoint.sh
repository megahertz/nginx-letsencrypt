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

log() {
  local text="$@"
  echo -e "\033[0;36m${text}\033[0m"
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

  log '#### acme.sh installed. Issuing a certificate...'

  nginx -c /cert/verify.conf
  acme.sh --issue --home /cert/data/acme.sh ${args} --webroot /cert/data/www

  log '#### Certificate received. Installing...'

  killall -9 nginx || true

  mkdir -p /cert/data/issued
  acme.sh --install-cert ${args} --home /cert/data/acme.sh \
    --key-file /cert/data/issued/key.pem  \
    --fullchain-file /cert/data/issued/cert.pem \
    --reloadcmd 'test -e /var/run/nginx.pid && nginx -s reload || true'

  log '#### Certificate installed.'
}

run_cron() {
  log '#### Running crond....'

  if [ -z "${LE_DEBUG}" ]; then
    crond -b
    exit 0
  fi

  # Patch crontab to execute renewal each minute and show logs
  sed -i 's#[0-9]* [0-9]* \* \* \*#* * * * *#; s# > /dev/null##' \
    /etc/crontabs/root

  crond -f -l 0 &
}

if [ ! -f /cert/data/issued/cert.pem ]; then
  log '#### Certificate not found. Initializing acme.sh...'
  install_acme
fi;

run_cron

log '#### Checking whether certificate should be renewed....'
acme.sh --cron --home /cert/data/acme.sh || true


log '#### Finally, running nginx....'
"$@"
