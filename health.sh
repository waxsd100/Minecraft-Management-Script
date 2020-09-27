#! /bin/bash
# * * * * * for i in `seq 0 10 59`;do (sleep ${i}; /bin/sh /var/minecraft/healthcheck/health.sh check >> /var/minecraft/healthcheck/log/`date +\%Y-\%m-\%d_healthcheck`.log 2>&1) & done;
# @daily find /var/minecraft/healthcheck/log/ -name '*.log' -mtime +30 -delete
cd "${0%/*}"
exec {lock_fd}< "$0"
flock --nonblock ${lock_fd} || exit 0

# 定数定義
declare -A WATCH_PROCESS;
MAILTO=""

YMD=`date '+%y/%m/%d %H:%M:%S'`

# 実行ユーザ定義
RUN_USER="root"

# 停止カウントダウン秒数
STOP_INTERVAL=30

# 停止コマンド
STOP_COMMAND="stop"

# ブロードキャストコマンド
BROADCAST_COMMAND="say"

# バックアップ設定
MC_BACKUP_FILE=`date '+%Y-%m-%d_%H'`
MC_BACKUP_DIR_BASE="/var/minecraft/backup/"

# Upload Dir
DRIVE_DIR=/mnt/google-drive/TUSB/Server-Storage/

# 表示設定
RESET=$'\e[0m'
BOLD=$'\e[1m'
RED=$'\e[1;31m'
GREEN=$'\e[1;32m'


# Import
. ./health.inc
source ./exception.sm


as_user() {
# ユーザ別実行
ME=`whoami`
    if [ ${ME} == ${RUN_USER} ] ; then
        bash -c "$1"
    else
        su - ${RUN_USER} -c "$1"
    fi
}

screen_shutdown(){
  # $1 screenName
  # $2 execCommand
  
  for pid in `screen -list | grep $1 | cut -f1 -d'.' | sed 's/\W//g'`
  do
    echo "${pid} killed"
    kill ${pid}
  done
}


screen_sender(){
  # $1 screenName
  # $2 execCommand
  
  for pid in `screen -list | grep $1 | cut -f1 -d'.' | sed 's/\W//g'`
  do
    SEND_SCREEN="screen -p 0 -S ${pid}.$1 -X eval"
    echo "[${YMD}] ${pid} $1 > $2" &
    wait
    as_user "${SEND_SCREEN} 'stuff \"$2\"\015'"
  done
}

start(){
  # $1 screenName
  # $2 shellCommand
  echo "[${YMD}] `sh $2 && echo "[${YMD}] $1 Up" || echo "[${YMD}] $1 Up Oops"`"
}

stop(){
  # $1 screenName
  # $2 ScreenCommand
  screen_sender $1 $STOP_COMMAND
  if [ $? = 0 ]; then
    echo "[${YMD}] $1 Down"
  else
    echo "[${YMD}] $1 Down Oops"
    screen_shutdown $1
  fi
}

count_wait(){
  for proc_screen in ${!WATCH_PROCESS[@]};
    do
    if [ -n "$1" ]; then
      screen_sender $proc_screen "${BROADCAST_COMMAND} $1"
    fi
    i=${STOP_INTERVAL}
    while [ ${i} -ne 0 ]
    do
      if [ ${i} -eq ${STOP_INTERVAL} ]; then
        screen_sender $proc_screen "${BROADCAST_COMMAND} ${STOP_INTERVAL} $2"
      else
        if test `expr ${i} % 15` -eq 0 -o ${i} -le 10; then
          screen_sender $proc_screen "${BROADCAST_COMMAND} ${i} $2"
        fi
      fi
      i=$((${i} - 1))
      sleep 1
    done
  done
}

# stop/start機能 #########################################################################################
mc_check(){
  for proc_screen in ${!WATCH_PROCESS[@]};
  do
    #監視するプロセスが何個起動しているかカウントする
    PROC_COUNT=`ps -ef | grep $proc_screen | grep -v grep | wc -l`
    
    # 監視するプロセスが0個場合に、処理を分岐する
    if [ $PROC_COUNT = 0 ]; then
    # 0の場合は、サービスが停止しているので起動する
      echo "[${YMD}] $proc_screen Dead"
      mc_start

    elif [ $PROC_COUNT -ge 2 ]; then
    # 1以上の場合は、サービスが過剰に起動しているので再起動する
      echo "[${YMD}] $proc_screen Over Running"
      # カウントダウン後 Stop / Start を行う
      STOP_INTERVAL=10
      mc_restart "プロセス異常を検知しました。" &
      wait
    else
    # サービス起動中
      echo "[${YMD}] $proc_screen Alive"
    fi
  done
  # echo -1000 > "/proc/`pidof java`/oom_score_adj"
  # echo $(ps -el | grep $(ps -el | grep SCREEN_SESSION_PID | grep bash | awk '{print $4}') | grep -v bash | awk '{print $4}')
}


# 起動処理 #################################################################################
mc_start(){
  for proc_screen in ${!WATCH_PROCESS[@]};
  do
    start $proc_screen ${WATCH_PROCESS[$proc_screen]}
  done
}

# 停止処理 #################################################################################
mc_stop(){
  count_wait "$1" "秒後に停止します。"
  for proc_screen in ${!WATCH_PROCESS[@]};
  do
    stop $proc_screen 
  done
}

# 再起動処理 #################################################################################
mc_restart(){
  count_wait "$1" "秒後に再起動します。"
  mc_stop
  sleep 3
  mc_start
}

# バックアップ処理 #################################################################################
mc_backup_world() {
for proc_screen in ${!WATCH_PROCESS[@]};
  do
    screen_sender $proc_screen "${BROADCAST_COMMAND} §9Auto Backup Start"
    screen_sender $proc_screen "save-all"
    screen_sender $proc_screen "save-off"
    MC_SERVER_NAME=`echo "${proc_screen}" | sed 's/minecraft-//g'`

    TARGET_DIR=`dirname ${WATCH_PROCESS[$proc_screen]}`
    MC_VER=`find "${TARGET_DIR}/" -type f -name "*.jar" | gawk -F/ '{print $NF}' | tr -cd '0123456789\n.' | awk '{ $a = substr($0, 2); sub(/.$/,"",$a); print $a }'`

    cd $TARGET_DIR
    for world in ${TARGET_WORLDS[@]};
    do 
      BACKUP_TO="${MC_BACKUP_DIR_BASE}${MC_VER}-${MC_SERVER_NAME}/${world}"
      mkdir -p $BACKUP_TO
      ZIP_FILE_NAME="${MC_SERVER_NAME}_${MC_BACKUP_FILE}.zip"
      ARCFILE="${BACKUP_TO}/${ZIP_FILE_NAME}"
      TARGET="${TARGET_DIR}/${world}"
      if [ -e ${TARGET} ]; then
        zip -r ${ARCFILE} ${world} 1>/dev/null &
        wait
        screen_sender $proc_screen "${BROADCAST_COMMAND} §aBackup Success ${ARCFILE}"
      fi
  done
  screen_sender $proc_screen "save-on"

  find ${MC_BACKUP_DIR_BASE} -name '*.zip' -mtime +3 -delete &
  wait
  screen_sender $proc_screen "${BROADCAST_COMMAND} §9Backup Complete"
  
  done
}


# 処理分岐 #########################################################################################
case "$1" in
    start)
      mc_start "$2"
      exit 0
      ;;
    stop)
      mc_stop "$2"
      exit 0
      ;;
    restart)
      mc_restart "$2"
      exit 0
        ;;
    check)
      mc_check "$2"
      exit 0
        ;;
    backup)
      mc_backup_world
      exit 0
      ;;
    *)
      echo "[${YMD}] command not found $1"
      exit 0
esac

exit 0
