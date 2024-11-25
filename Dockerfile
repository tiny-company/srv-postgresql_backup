ARG DEBIAN_VERSION=12-slim
FROM debian:${DEBIAN_VERSION}
LABEL org.opencontainers.image.authors="ottomatic"

USER root

ENV WORKDIR=/srv
RUN mkdir -p ${WORKDIR} \
    && mkdir -p /etc/cron.d

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    logrotate \
    postgresql-client \
    restic \
    curl \
    cron \
    rclone \
    && rm -rf /var/lib/apt/lists/*

COPY --chmod=644 resticprofile ${WORKDIR}/resticprofile
COPY --chmod=744 shell_modules ${WORKDIR}/shell_modules
COPY --chmod=744 main_postgresql_backup.sh ${WORKDIR}/main_postgresql_backup.sh
COPY --chmod=744 cron/cron_entrypoint.sh /cron_entrypoint.sh

RUN touch /var/log/cron.log

# Set the default command to run our entrypoint script
CMD ["/cron_entrypoint.sh"]
