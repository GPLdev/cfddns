# Dynamic DNS (DDNS) - Cloudflare API Client
<img alt="License" src="https://img.shields.io/github/license/GPLdev/cfddns?color=blue&style=plastic"> <img alt="Last commit" src="https://img.shields.io/github/last-commit/GPLdev/cfddns/main?color=blue&style=plastic"> <img alt="Stars" src="https://img.shields.io/github/stars/GPLdev/cfddns?color=blue&style=plastic">

Simple bash script for updating the public dynamic IP address to an existing Cloudflare DNS record. The script avoids unnecessary requests and keeps logs, checking for IP changes through DNS, STUN, and HTTPS. Simplify your system management by using simple scripts for straightforward tasks. Don't overcomplicate things by using complex software for simple API calls.

## Requirements

- ``curl`` - CLI tool for transferring data with URLs ([docs](https://curl.se/))
- ``jq`` - CLI JSON processor ([docs](https://stedolan.github.io/jq/))
- ``myip`` - Get your external IP address from public STUN servers ([docs](https://github.com/Snawoot/myip))
- ``APIv4`` - Cloudflare account ([docs](https://developers.cloudflare.com/api))
- ``crontab`` - Schedule of cron entries ([playground](https://crontab.guru/))

## Get Started

Begin by downloading the files from GitHub:

```
git clone https://github.com/GPLdev/cfddns.git
```
or
```
wget https://github.com/GPLdev/cfddns/archive/refs/heads/main.zip -O cfddns.zip; unzip cfddns.zip; rm cfddns.zip
```
Move the script to the /opt directory to ensure that all necessary dependencies are properly configured and that the script runs smoothly:
```
sudo mv cfddns /opt/cfddns
```
Add an execute permission to the sh file to avoid permission denied errors during executions:
```
sudo chmod +x /opt/cfddns/cfddns.sh
```
Now you have to install myip by downloading a [pre-built binary release](https://github.com/Snawoot/myip/releases/latest) according to your platform (e.g., myip.linux-arm for Raspberry Pi or myip.linux-amd64 for generic x64 architecture):
```
wget https://github.com/Snawoot/myip/releases/download/v1.2.0/myip.linux-amd64
```
To ensure that the necessary dependencies are met, please move the binary file to the same directory as the script and rename it as 'myipstun':
```
sudo mv myip.linux-amd64 /opt/cfddns/myipstun
```
Add an execute permission to 'myipstun' to avoid permission denied errors during executions:
```
sudo chmod +x /opt/cfddns/myipstun
```
To obtain your API token and Zone ID for your Cloudflare account, log in and navigate to the Overview section for your domain. On the right side of the page, you will find your API Zone ID and a link to generate an API token. Create an 'Edit Zone DNS' token and save it along with your API Zone ID.

Open the 'config.json' file and fill in the required data as per the example already provided in the file:
```
sudoedit /opt/cfddns/config.json
```
You can specify as many domains or subdomains as you need, regardless of whether they are attached to different Cloudflare accounts. Later, you can add additional domains to the configuration file, and the script will automatically detect and manage any new domains at the next scheduled cron execution.
```json
[
    {
        "domain": "example.com",
        "ttl": "3600",
        "proxy": "false",
        "zoneid": "<API Zone ID>",
        "token": "<API Zone Edit Token>"
    },
    {
        "domain": "sub.example.com",
        "ttl": "3600",
        "proxy": "false",
        "zoneid": "<API Zone ID>",
        "token": "<API Zone Edit Token>"
    }
]
```
To test the installation of your script and verify that everything is running smoothly, run a test execution that will create log files:
```
sudo /opt/cfddns/cfddns.sh
```
Finally, create a cron job as a sudoer or root user to automate your script's execution at your desired time interval. For easy monitoring, consider adding a log file to your cron job, allowing you to review the results of the latest script execution at any time:
```
sudo crontab -e
```
To run a cron job every 5 minutes and save the results to a log file, add this line at the end of the file:
```
*/15 * * * * /opt/cfddns/cfddns.sh > /opt/cfddns/logs/cron.log 2>&1
```
To check the results of the script's last cron execution, use the following command:
```
sudo cat /opt/cfddns/logs/cron.log
```
You can either use [crontab.guru](https://crontab.guru/) or the schema below to create your own cron job instructions:
```bash
# ┌───────────── minute (0 - 59)
# │ ┌───────────── hour (0 - 23)
# │ │ ┌───────────── day of the month (1 - 31)
# │ │ │ ┌───────────── month (1 - 12)
# │ │ │ │ ┌───────────── day of the week (0 - 6) (Sunday to Saturday 7 is also Sunday on some systems)
# │ │ │ │ │ ┌───────────── command to issue                               
# │ │ │ │ │ │
# │ │ │ │ │ │
# * * * * * /opt/cfddns/cfddns.sh {full path to the script}
```
## Tested Environment
- Ubuntu 22.04 LTS (Jammy Jellyfish)
- Debian GNU/Linux 11 (Bullseye)
- Raspberry Pi OS _arm32_ 
- Raspberry Pi OS _arm64_ 
