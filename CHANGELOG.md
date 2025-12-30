# Changelog

All notable changes to this project will be documented in this file.

## [1.9.4] - Service release

- Dropping support for Ubuntu 20.04 for new installs

### Bug fixes

- Fix: 421 error on all web and mail domains after Apache 2.4.64 update (#5058)
- Fix: Set default SOA retry value to 1800 for DENIC compliance (#5030)
- Fix domain alias replacement logic when changing web domain (Fixes #5015) (#5041)
- Fix ipv4_cidr validation (#5044)
- Update magento.tpl / magento.stpl for healthcheck support (#5036)
- Add: Show user and bandwidth quota in the dashboard
- Sort backup file list before retention check (Fixes #5017) (#5018)
- Improve logging of Spamhaus DQS lookups without exposing query key (#5011)
- Bump Roundcube to version 1.6.11
- Remove the apache2-suexec-pristine package from the Debian installer
- Fix(#4979): Fixes domain redirects not being suspended (#4991)
- Ensure newline at end of hestiaweb user crontab (#4992)
- Allow slash when adding username to smtp relay (Fixes #4973) (#4974)
- fix: prevent empty user variable from affecting multiple scripts (Fixes #4926) (#4928)
- Fix editing Panel Cronjobs for hestiaweb (#4891)
- Fix missing dependency proftpd-mod-crypto on Ubuntu (#4895)
- Fix the way Hestia validates chain certificate (#4887)

## [1.9.3] - Service release

### Bug fixes

- Fix deleting snapshot not working #4812
- Fix bulk restore
- Set priority to a lower value for backup process and limit disk speed and upload speed #4853
- Fix sftp homedir staring in /home and not /home/{user} (#4862)
- Temp workaround for Ubuntu 24.04 i18n GUI support (#4857)
- Fix multiple smaller bugs with incremental backups (#4861)
- SFTP get completely disabled in certain setups when enableling it (#4859)
- mysqladmin got renamed on MariaDB systems to mariadb-admin (#4850)
- Update dummy.conf (#4855)
- Avoid warning using pgrep if service name has 15 or more characters (#4851)
- Move v-update-letsencrypt-ssl cron to /var/spool/cron (#4823)
- Update v-add-remote-dns-host (#4837)
- Fix bug in v-add-web-domain-ssl (#4835)
- Fix bug in v-update-user-stats (#4842)
- Fix output v-dump-database (#4831)
- Update configuration.php (#4827)
- Include at as an dependency (#4829)
- Replace is_restart_valid with is_restart_format_valid
- Replaced "echo" with "sed" to avoid "Permission denied" in multiple commands (#4818 #4819 #4817 #4186)
- Admin are unable to add access keys #4799 (#4810)
- Make jail for work sftp by using the binary sftp-server (#4803)
- Update v-add-mail-domain (#4868)


### Dependencies

- Bump Roundcube version to 1.6.10 (#4813)

## [1.9.2] - Service release

- Backups change owner files to hestiaweb (#4779)
- PHP-FPM Include missing info (#4766)
- Fix bug where PHPMyadmin / PHPPGadmin where named phpmyadmin in 1.9.0 if this is the case it will reset to phppgadmin (#4767)
- Fix warning caused by some old jailed code left (#4751)
- Update <www.conf> (#4743)

## [1.9.1] - Service release

- Fixed an issue with webmail / phpmydmin unavailble
