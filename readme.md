# srv-postgresl_backup

## Description

A dokerized shell script that backup up a postgresql database based on cron, restic, pg_dump.

🐳 Image is build anb pushed to dockerhub at [postgresql_backup](https://hub.docker.com/repository/docker/tinycompany/postgresql_backup/general)

⚡ features :
- disk space size check
- store backup locally and apply rotation
- send backup to distant s3 storage (using restic)

@TODO :
- hadolint

💖 Credits to :
- [monlor](https://github.com/monlor/docker-cron) : for cron docker image.

## Usage

1. First set the env var (i.e : with "env" or "env_file" arg for docker-compose) :

- mandatory variables :
    - `CRON_JOB_<name> : Define cron jobs. Format: `"<schedule> <command>"`, example : `"* * * * * echo 'Hello, World!'"`
    - `POSTGRES_DB_LIST` : list of database name to backup
    - `POSTGRES_HOST` : postgresql hostname or ip address
    - `POSTGRES_PORT` : postgresql database port
    - `POSTGRES_USERNAME` : postgresql user
    - `POSTGRES_PASS` : postgresql password
    - `RESTIC_REPOSITORY` : (mandatory if using restic) restic repository
    - `RESTIC_PASSWORD` : (mandatory if using restic) restic repository's password
    - `AWS_ACCESS_KEY_ID` : (mandatory if using restic) S3 access key
    - `AWS_SECRET_ACCESS_KEY` : (mandatory if using restic) S3 secret access key

- not mandatory :
    - `FEATURE_SIZE_CHECK` : (default : false) Activate disk size check feature.
    - `FEATURE_BACKUP_ROTATION` : (default : false) Activate backup rotation feature.
    - `FEATURE_RESTIC` : (default : true) Activate restic feature.
    - `WORKDIR` : (default : /root) default workdir for script
    - `BACKUP_NAME` : (default : postgresql) the backup folder
    - `BACKUP_BASE_DIR` : (default : /backup/webdrone) the backup path
    - `BACKUP_POSTGRES_DIR_MOUNT_POINT` : (default : backup) the mount point where BACKUP_BASE_DIR is to check disk space available
    - `POSTGRES_DB_LIST` : (default : meveo) the database list to backup
    - `PGPASSFILE` : (default : /root/.pgpass) the path to store the postgresql database credential
    - `BACKUP_FORMAT` : (default : c) can be either one p,c,d,t (see [pg_dump official documentation](https://docs.postgresql.fr/13/app-pgdump.html))
    - `BACKUP_PARALELL_THREAD` : ( default : 1) to speed up the backup process by launching parallel thread.
    - `BACKUP_COMPRESSION_LEVEL` : (default : 0) compression level for the backup
    - `BACKUP_DAILY_COUNT` : (default : 6) backup day number to keep (older will be deleted)
    - `DB_DUMP_ENCRYPTION`: (default : true) boolean value specifying if you need the backups to be encrypted
    - `LOG_DIR` : (default : /var/log/webdrone)
    - `LOG_FILE`: (default : "${LOG_DIR}/backup_script.log")
    - `LOG_STD_OUTPUT` : (default : false) boolean value specifying if logs are send to file or standtard output.
    - `PG_READY_RETRY_THRESHOLD` : (default :  3) threshold for maximum retry
    - `PG_READY_RETRY_WAIT_TIME` : (default : 120s) time to wait between each pg_isready test
    - `RESTIC_TAG` :  (default : postgresql_backup) additional custom tag for restic
    - `AWS_DEFAULT_REGION` : (default : fr-par) default region to use in S3 header
    - `RESTICPROFILE_CONFIG_PATH` : (default : /rpool/encrypted/resticprofile) default restic profile config path
    - `RESTICPROFILE_PASSWORD_LENGTH` : (default : 2048) password length to generate if not define
    - `RESTICPROFILE_PASSWORD_FILENAME`: (default :password.key) file that store restic repository's password
    - `PROMETHEUS_URL` : prometheus address to send metrics (9091)

[look at a very simple .env file example here](./.example.env)

2. Then launch container using docker compose, check [docker-compose example file](./docker-compose.yml).

```
docker compose up -d
```

## Sources :

### cron

- [docker image for cron usage by monlor](https://github.com/monlor/docker-cron)

### Postgresql backup

- [docker-pg-backup](https://github.com/kartoza/docker-pg-backup/tree/master)

### Restic

- [restic and postgresql backup script](https://github.com/mhw/restic-backup-scripts/blob/main/postgresql-backup.sh)
- [Recipe to snapshot postgres container with restic](https://forum.restic.net/t/recipe-to-snapshot-postgres-container/1707)
- [restic backup to scw S3 tutorial](https://www.scaleway.com/en/docs/tutorials/restic-s3-backup/)
- [Full guide to backup with restic](https://helgeklein.com/blog/restic-encrypted-offsite-backup-for-your-homeserver/)

### Restiprofile

- [restiprofile config example](https://creativeprojects.github.io/resticprofile/configuration/examples/index.html)

### Other backup solution

- [restic-compose-backup](https://github.com/ZettaIO/restic-compose-backup/tree/master)

### Github action

- [old original shellcheck github action](https://github.com/marketplace/actions/shellcheck-github-action)
- [new shellcheck github action](https://github.com/nuwaycloud/shellcheck-action)