ARG DEBIAN_VERSION=12-slim
FROM debian:${DEBIAN_VERSION}
LABEL org.opencontainers.image.authors="ottomatic"

USER root

ENV WORKDIR=/srv
RUN mkdir -p ${WORKDIR}

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    restic \
    curl \
    rclone \
    jq \
    bc \
    wget \
    gnupg2 \
    lsb-release \
    && rm -rf /var/lib/apt/lists/*

## install specific postgresql-client version
RUN echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list && \
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - && \
    apt-get update && \
    apt-get install -y \
        postgresql-client-13 && \
        # postgresql-client-15 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY --chmod=744 shell_modules ${WORKDIR}/shell_modules
COPY --chmod=744 main_postgresql_backup.sh ${WORKDIR}/main_postgresql_backup.sh
COPY --chmod=744 main_postgresql_restore.sh ${WORKDIR}/main_postgresql_restore.sh
COPY --chmod=744 entrypoint/entrypoint.sh /entrypoint.sh

RUN ln -s /entrypoint.sh /usr/bin/backup

ENTRYPOINT ["/entrypoint.sh"]

CMD ["cron_backup"]