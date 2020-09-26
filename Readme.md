0. BungeecordServer Install
1. `yum install screen`
2. Create a log directory `make /var/log/healthcheck`
3. Edit the configuration file (put it in the same directory)
```
WATCH_PROCESS=(
 ["ScreenSessionName_01"]="Execution shell file path"
 ["ScreenSessionName_02"]="Execution shell file path"
)

# Multiple definitions.
```
4. add `crontab -e`
```
# HealthCheck 
* * * * * for i in `seq 0 10 59`;do (sleep ${i}; /bin/sh /usr/local/sbin/health.sh >> /var/log/healthcheck/`date +\%Y-\%m-\%d_healthcheck`.log 2>&1) & done;
@daily find /var/log/healthcheck/ -name '*.log' -mtime +30 -delete
```
It runs once every 10 seconds.
Please change the location of the execution file and so on as needed.


5. Advanced Settings
If you want to change the following settings, change the variables in health.sh

Changes the user who runs the script. L14

```
RUN_USER="root"
```
Change the countdown timer until it stops. L17
```
STOP_INTERVAL=60
```
Sets the command to be sent to ScreenSession when stopped. L20
```
STOP_COMMAND="end"
```

TODO:
I want to put the Advanced settings in the ConfigFile