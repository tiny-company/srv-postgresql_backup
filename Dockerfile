ARG DEBIAN_VERSION=12-slim
FROM debian:${DEBIAN_VERSION}
LABEL org.opencontainers.image.authors="ottomatic"

USER root

ENV WORKDIR=/srv
RUN mkdir -p ${WORKDIR}

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    postgresql-client \
    restic \
    curl \
    rclone \
    && rm -rf /var/lib/apt/lists/*

COPY --chmod=744 shell_modules ${WORKDIR}/shell_modules
COPY --chmod=744 main_postgresql_backup.sh ${WORKDIR}/main_postgresql_backup.sh
COPY --chmod=744 main_postgresql_restore.sh ${WORKDIR}/main_postgresql_restore.sh
COPY --chmod=744 entrypoint/entrypoint.sh /entrypoint.sh

RUN ln -s /${WORKDIR}/main_postgresql_backup.sh /usr/bin/backup && \
    ln -s /${WORKDIR}/main_postgresql_restore.sh /usr/bin/restore

ENTRYPOINT ["/entrypoint.sh"]

CMD ["cron_backup"]