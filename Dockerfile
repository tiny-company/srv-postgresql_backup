ARG DEBIAN_VERSION=12-slim
FROM debian:${DEBIAN_VERSION}
LABEL org.opencontainers.image.authors="ottomatic"

USER root

ENV WORKDIR=/root
RUN mkdir -p ${WORKDIR}

RUN apt-get install -y --no-install-recommends \
        tini \
        logrotate \
        dcron \
        postgresql-client \
        restic \
        curl \
        cron \
        rclone \
    && rm -rf /var/lib/apt/lists/*

COPY --chmod=644 resticprofile srv/resticprofile
COPY --chmod=644 shell_modules srv/shell_modules
COPY --chmod=644 main_postgresql_backup.sh srv/main_postgresql_backup.sh
# COPY --chmod=644 cron/psl_backup_cron /etc/cron.d/psl_backup_cron
COPY --chmod=744 cron/cron_entrypoint.sh /cron_entrypoint.sh

RUN touch /var/log/cron.log

# Use tini as the entry point
ENTRYPOINT ["/sbin/tini", "--"]

# Set the default command to run our entrypoint script
CMD ["/entrypoint.sh"]
