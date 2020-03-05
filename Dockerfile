FROM nginx:1.17.9-alpine
EXPOSE 80 443
ENV LE_DOMAINS='' \
    LE_EMAIL='' \
    LE_DEBUG=''

RUN apk add --no-cache acme.sh ca-certificates openssl tini

COPY root /

ENTRYPOINT ["tini", "--", "/cert/entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]
