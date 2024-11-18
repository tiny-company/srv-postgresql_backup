ARG DEBIAN_VERSION=12-slim
FROM debian:${DEBIAN_VERSION}
LABEL org.opencontainers.image.authors="ottomatic"

USER root

ENV WORKDIR=/root
RUN mkdir -p ${WORKDIR}

RUN apt-get update && apt-get install -y \
        postgresql-client \
        restic \
        curl \
        cron \
        rclone

COPY --chmod=644 resticprofile srv/resticprofile
COPY --chmod=644 shell_modules srv/shell_modules
COPY --chmod=644 main_postgresql_backup.sh srv/main_postgresql_backup.sh
COPY --chmod=644 cron/psl_backup_cron /etc/cron.d/psl_backup_cron

RUN touch /var/log/cron.log
CMD ["cron", "-f"]

#ENTRYPOINT ${WORKDIR}/main_postgresql_backup.sh
