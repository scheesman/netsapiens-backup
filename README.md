# netsapiens-backup
Backup script to back up from NetSapiens to AWS S3 and Google Cloud Storage.  Script is based on recommendations found [here](https://help.netsapiens.com/hc/en-us/articles/205235690-What-Commands-Should-I-Execute-For-Scheduled-Backups-).  I created this script so I could have a single script on all servers that had the flexibility to back up just the modules installed on that server.  Also, by leveraging S3 buckets, you can utilize Amazon's built in expiration policy and expire files as appropriate for your organization.

File structure in the buckets will be organized by hostname and service type: `bucketname->hostname->Service_date.gz`

## Instructions
Copy the script to the location of your choice.  Change relevant options in the script, such as user, password, .s3cfg location, storage type, etc.  Run script manually or via crontab.

## Requirements
* s3cmd - install via `sudo apt-get install s3cmd`
or
* gsutil - install via ????
* Amazon S3 or Google Cloud Storage bucket with appropriate permissions
* Properly configured .s3cfg file for AWS S3 usage.  Should just require setting the access_key and secret_key.  Can be completed with `s3cmd --comfigure`.  Should output file into `/opt/.s3cfg`
* gsutil configuration.  Can be completed via `gcloud init`

## Usage
The script takes up to 9 parameters.  You can specify anywhere from 1 to 6, depending on your needs.

Options: `core`, `cdr`, `cdr2`, `cdr2last`, `conference`, `messaging`, `ndp`, `ndpfiles`, `recording`

### core
`core` backs up the Core module configuration without CDRs.

### cdr
`cdr` backs up the Core module CDRs.  This option only backs up the last 25 hours, so you will want to run this option once per day.

### cdr2
`cdr2` backs up current month's CDR2 files.  This should be run every day as it only backs up the current month's tables.

### cdr2last
`cdr2last` backs up the previous month's CDR2 tables.  This should only be run once a month as these files are huge and they do not change.

### conference
`conference` backs up the Conferencing module.

### messaging
`messaging` backs up the MessagingDomain db and all included dables.  Should be run once a day.

### ndp
`ndp` backs up the Endpoints module.

### ndpfiles
`ndpfiles` backs up the /frm folder and all of its contents.  This option was added separate from the `ndp` option as you probably don't want to back this up every night.

### recording
`recording` backs up the Recording module.

## Examples

Back up all services on a single box:

`nsbackup.sh core cdr conference ndp ndpfiles recording`

Back up just Core (NDP) files:

`nsbackup.sh core cdr conference`

## gsutil installation

gsutil isn't included in the default Ubuntu repositories so you will have to add it yourself.

`echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list`

`apt-get install apt-transport-https ca-certificates`

`curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -`

`sudo apt-get update && sudo apt-get install google-cloud-sdk`

`gcloud init`

## crontab
You will probably want to run these via crontab.  Below are the crontab entries I use, depending on the roles installed.  Just `sudo crontab -e` and insert what's relevant for you.  If you need help with crontab schedules, I highly recommend https://crontab-generator.org/.

`0 3 * * * /usr/local/scripts/nsbackup.sh core cdr conference ndp recording > /var/log/backups.log`

`30 0 * * 0 /usr/local/scripts/nsbackup.sh ndpfiles > /var/log/backups.log`
