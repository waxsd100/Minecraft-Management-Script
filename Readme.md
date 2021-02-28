#  minecraft Server Health Check and Management Script

see BungeeCord version   
https://gist.github.com/waxsd100/1d80bc70a07ebbaeccaa5bd98ed99168

0. Minecraft Server Install
1. `yum install screen jq`
2. Create a log directory `make /var/log/healthcheck`
3. Edit the configuration file (put it in the same directory)
```
WATCH_PROCESS=(
 ["ScreenSessionName_01"]="Execution shell file path"
 ["ScreenSessionName_02"]="Execution shell file path"
)

# Multiple definitions.

# BACKUP TARGET World
TARGET_WORLDS=("world" "world_nether" "world_the_end")


```
4. add `crontab -e`
```
# HealthCheck 
* * * * * for i in `seq 0 10 59`;do (sleep ${i}; /bin/sh /var/minecraft/healthcheck/health.sh check >> /var/minecraft/healthcheck/log/`date +\%Y-\%m-\%d_healthcheck`.log 2>&1) & done;
@daily find /var/minecraft/healthcheck/log/ -name '*.log' -mtime +30 -delete
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
STOP_COMMAND="stop"
```

TODO:
I want to put the Advanced settings in the ConfigFile

（TODO Doc）
# Use Command 
start)
 Start Minecraft Server    
 HealthCheck will also be added to the Cron Job   
 
stop)   
 Stop Minecraft Server    
 HealthCheck will also be delete to the Cron Job   
   
restart)   
 Restart Minecraft Server    
   
check)   
Check whether the server is starting or stopping   
   
backup)   
Create BackUp   


## LICENSE   
These codes are released under the MIT License, see LICENSE.
