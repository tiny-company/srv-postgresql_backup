ARG DEBIAN_VERSION=12-slim
FROM debian:${DEBIAN_VERSION}
LABEL org.opencontainers.image.authors="ottomatic"

USER root

ENV WORKDIR=/root
RUN mkdir -p ${WORKDIR} \
    && mkdir -p /etc/crontabs/

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    tini \
    logrotate \
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
ENTRYPOINT ["/bin/tini", "--"]

# Set the default command to run our entrypoint script
CMD ["/cron_entrypoint.sh"]
