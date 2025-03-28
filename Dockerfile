FROM elixir:alpine

ARG PLEROMA_VER=v2.9.1
ARG UID=911
ARG GID=911
ENV MIX_ENV=prod

RUN echo "http://nl.alpinelinux.org/alpine/latest-stable/main" >> /etc/apk/repositories \
    && apk update \
    && apk add git gcc g++ musl-dev make cmake file-dev \
    exiftool imagemagick libmagic ncurses postgresql-client ffmpeg \
    ca-certificates openssl-dev

RUN addgroup -g ${GID} pleroma \
    && adduser -h /pleroma -s /bin/false -D -G pleroma -u ${UID} pleroma

ARG DATA=/var/lib/pleroma
RUN mkdir -p /etc/pleroma \
    && chown -R pleroma /etc/pleroma \
    && mkdir -p ${DATA}/uploads \
    && mkdir -p ${DATA}/static \
    && chown -R pleroma ${DATA}

COPY ./config.exs /etc/pleroma/config.exs

RUN chown -R pleroma /etc/pleroma
RUN chmod o= /etc/pleroma/config.exs
RUN chmod g-w /etc/pleroma/config.exs


USER pleroma
WORKDIR /pleroma

RUN git clone -b develop https://git.pleroma.social/pleroma/pleroma.git /pleroma \
    && git checkout ${PLEROMA_VER}

RUN wget https://gitlab.com/soapbox-pub/soapbox/-/jobs/artifacts/v3.2.0/download?job=build-production -O soapbox-fe.zip
RUN mkdir -p ${DATA}/static/frontends
RUN busybox unzip -q -d ${DATA}/static/frontends/soapbox soapbox-fe.zip
RUN rm soapbox-fe.zip

RUN wget https://github.com/DejavuMoe/Smoji/archive/refs/heads/master.zip -O smoji.zip
RUN busybox unzip -q -d ${DATA}/static smoji.zip
RUN mv ${DATA}/static/Smoji-master ${DATA}/static/emoji
RUN rm ${DATA}/static/emoji/.gitignore ${DATA}/static/emoji/LICENSE ${DATA}/static/emoji/README.md
RUN rm smoji.zip

COPY ./static/* ${DATA}/static/frontends/soapbox/static/

RUN echo "import Mix.Config" > config/prod.secret.exs \
    && mix local.hex --force \
    && mix local.rebar --force \
    && mix deps.get --only prod \
    && mkdir release \
    && mix release --path /pleroma

EXPOSE 4000

ENTRYPOINT ["/pleroma/docker-entrypoint.sh"]
