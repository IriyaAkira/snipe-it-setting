# snipe-it-setting
## Getting Start
Execute the following in your home directory or similar location:
```bash
git clone https://github.com/IriyaAkira/snipe-it-setting.git snipe-it
curl https://raw.githubusercontent.com/snipe/snipe-it/master/.env.docker --output .env
```
Edit ./snipe-it/.env
```yaml
# Extract only the parts that need to be changed.
APP_URL=http://www.example.com
APP_TIMEZONE='Asia/Tokyo'
DB_PASSWORD=changeme1234
MYSQL_ROOT_PASSWORD=changeme1234
# Add For Backup
BK_SERVER=HOSTNAME
BK_SHARE=SHARENAME
MOUNT_POINT=/mnt/foo/bar
```
Edit /root/.smbcredentials For backup.
```yaml
username=smbuser
password=secretpassword
domain=WORKGROUP
```
By executing the command below, you can change whether to use HTTP only or HTTPS only.
```bash
cd ./snipe-it/nginx/conf.d
# If you want to use HTTP.
ln -sf snipe-it.conf.http snipe-it.conf
# If you want to use HTTPS.
ln -sf snipe-it.conf.https snipe-it.conf
```
However, in the case of HTTP, you need to execute the following script or prepare a dummy certificate by other methods.
```bash
./snipe-it/scripts/create_dummy_self-singed_certificate.sh

# When the above script is executed, rewrite the corresponding section of the following file for dummy use.
vi ./snipe-it/nginx/conf.d/phpiapm.conf.http
    ssl_certificate     /etc/nginx/certs/dummy.crt;
    ssl_certificate_key /etc/nginx/certs/dummy.key;
```

Run the following as root.  
Executing this will complete the cron setup for daily project backups and the launch of the service.
```bash
./snipe-it/scripts/start.sh
```

## Lisence
This repository does not contain any application code or Docker images.

It only provides scripts to pull and run the official snipe-it Docker image:
- https://hub.docker.com/r/snipe/snipe-it/

Please refer to the original project and Docker image page for license information.