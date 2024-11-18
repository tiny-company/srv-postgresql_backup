ARG DEBIAN_VERSION=12-slim
FROM debian:${DEBIAN_VERSION}
LABEL org.opencontainers.image.authors="ottomatic"
# USER root
ENV WORKDIR=/root
ENV RESTICPROFILE_CONFIG_PATH=/root/resticprofile
ENV RESTICPROFILE_PASSWORD_FILENAME=password.key
ENV AWS_DEFAULT_REGION=fr-par

RUN apt-get update && apt-get install -y \
        postgresql-client restic curl

RUN mkdir -p ${WORKDIR}
COPY . ${WORKDIR}/
RUN chmod +x ${WORKDIR}/main_postgresql_backup.sh

ENTRYPOINT ${WORKDIR}/main_postgresql_backup.sh


RUN apt-get update && apt-get install -y cron

#################################""
# Copy the script and cron file
COPY your-script.sh /usr/local/bin/your-script.sh
COPY crontab /etc/cron.d/your-crontab

# Give execution rights on the cron job
RUN chmod 0644 /etc/cron.d/your-crontab

# Apply cron job
RUN crontab /etc/cron.d/your-crontab

# Create the log file to be able to run tail
RUN touch /var/log/cron.log

# Run the command on container startup
CMD cron && tail -f /var/log/cron.log
