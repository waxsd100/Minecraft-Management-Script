#! /bin/bash
#
# Usage: Minecraft Health Check & Backup Script [script mode] [option]
#
#   Prerequisite software: jq, pv, screen
#   Unexpected results can occur.
#   Be sure to configure the Config file before running.
# Options:
#
#   start    Minecraft Server Start and CronJob append
#   stop     Minecraft Server Stop and CronJob remove
#   restart  Minecraft Server restart
#   check    Minecraft Server Start or Stop check
#   backup   Minecraft Server Backup
#
# Arguments:
#
#   stop / restart [stop interval] [message]
#
#            [stop interval] Specifies the number of seconds before stopping.
#                           (If left blank, the default setting will be used.)
#
#            [message] Send a broadcast message to the server before stopping
#
# Twitter: wakokara
# GitHub: waxsd100
# Version: 0.0.3

VERSION="0.0.3"
exec {lock_fd}< "$0"
flock --nonblock ${lock_fd} || echo "[ERROR] Duplicate startup"
cd "${0%/*}" > /dev/null 2>&1 || :
declare -A SERVER_PROPERTIES;
declare -A EXEC_COMMAND;

readonly ME_FILE=$(basename $0)
readonly SCRIPT_DIR=$(cd -- "$(dirname -- "$1")" && pwd)
#readonly SCRIPT_DIR=$(cd $(dirname $0); pwd)
readonly SCRIPT_PATH="${SCRIPT_DIR}/${ME_FILE}"
readonly LOG_DIR="$(cd .. "$(dirname -- "$1")" && pwd)/log/"

readonly LOCAL_IP=`ip -f inet -o addr show eth0|cut -d\  -f 7 | cut -d/ -f 1`

# 表示設定
readonly BOLD=$'\e[1m'
readonly RED=$'\e[1;31m'
readonly GREEN=$'\e[1;32m'
readonly RESET=$'\e[0m'
readonly YMD=$(date '+%y/%m/%d %H:%M:%S')


# Import
. ../config.inc
. ../health.inc
source ../exception.sm

send_discord() {
  # Discord Webhook Sender
  title="$1"
  description="$2"
  footer="$3"
  color="$4"

  if "${DISCORD_NOTICE}"; then
    curl -LsS https://raw.githubusercontent.com/ChaoticWeg/discord.sh/master/discord.sh | bash -s -- \
      --title "${title}" \
      --description "${description}" \
      --footer "${footer}" \
      --color "${color}" \
      --webhook-url "${DISCORD_WEB_HOOK_URL}" \
      --timestamp
  fi
}


as_user() {
# ユーザ別実行
  ME=`whoami`
    if [ ${ME} == ${RUN_USER} ] ; then
        bash -c "$1"
    else
        su - ${RUN_USER} -c "$1"
    fi
}


screen_sender(){
  # $1 screenName
  # $2 execCommand
  proc_screen="$1"
  screen_name="${SCREEN_PREFIX}-${proc_screen}"
  pid_list=$(as_user "screen -list | grep $screen_name | cut -f1 -d'.' | sed 's/\W//g'")
  for pid in $pid_list
  do
    SEND_SCREEN="screen -p 0 -S ${pid}.$screen_name -X eval"
    echo "[${YMD}] ${pid} $1 > $2"
    as_user "${SEND_SCREEN} 'stuff \"$2\"\015'"
  done
}

start(){
  # $1 screenName
  # $2 shellCommand
  proc_screen="$1"
  screen_name="${SCREEN_PREFIX}-${proc_screen}"
  target_dir="${2%/}"
  screen_exec=`echo "screen -AmdS ${screen_name} ${EXEC_COMMAND[$1]}"`

  if [ -d "$target_dir/" ]; then
cat <<'EOF' > "$target_dir/run.sh"
#!/bin/sh
cd "${0%/*}" > /dev/null 2>&1
EOF
  echo "${screen_exec}" >> "$target_dir/run.sh"
  echo "#Version: ${VERSION}" >> "$target_dir/run.sh"
  echo [$YMD] $(chown "${RUN_USER}":"${RUN_USER}" "$target_dir"/run.sh -v)

  fi
  exitCode=0
  PROC_COUNT=`ps -ef | grep $screen_name | grep -v grep | wc -l`
  if [ $PROC_COUNT = 0 ]; then
    as_user "/bin/sh $target_dir/run.sh" || exitCode=$?
    if [ "$exitCode" = 0 ]; then
      echo "[${YMD}] [$proc_screen] Up"
      send_discord "[$proc_screen] Server Start" "${OUT}" "${LOCAL_IP}" "0x2ECC71"
    else
      echo "[${YMD}] [$proc_screen] Up Oops"
      send_discord "[$proc_screen] Server Start Oops..." "${OUT}" "${LOCAL_IP}" "0x2ECC71"
    fi
  else
    echo "[${YMD}] [$proc_screen] is up and running"
    send_discord "[$proc_screen] is up and running..." "${OUT}" "${LOCAL_IP}" "0x2ECC71"
  fi
}

stop(){
  # $1 screenName
  # $2 ScreenCommand
  proc_screen="$1"
  screen_sender $proc_screen $STOP_COMMAND
  if [ $? = 0 ]; then
    OUT=`echo "[${YMD}] [$proc_screen] Down"`
  else
    OUT=`echo "[${YMD}] [$proc_screen] Down Oops"`
    pid_list=$(as_user "screen -list | grep $screen_name | cut -f1 -d'.' | sed 's/\W//g'")
    for pid in $pid_list
    do
      echo "${pid} killed"
      kill ${pid}
    done
  fi
  send_discord "$proc_screen Server Stop" "${OUT}" "${LOCAL_IP}" "0xE91E63"

}

count_wait(){
  # $1 count wait time(sec)
  # $2 send notice server message
  # $3 init notice server message
  if [ -n "$1" ]; then
    if [[ "$1" =~ ^[0-9]+$ ]];then
      interval=$(expr $1)
    else
      interval=$STOP_INTERVAL
      echo "[ERROR] $1 is not a number. to set interval $interval"
    fi
  else
    interval=$STOP_INTERVAL
  fi

  for proc_screen in ${!SERVER_PROPERTIES[@]};
    do
    screen_name="${SCREEN_PREFIX}-${proc_screen}"
    PROC_COUNT=`ps -ef | grep $screen_name | grep -v grep | wc -l`
    if [ $PROC_COUNT != 0 ]; then
      i=${interval}
      if [ -n "$3" ]; then
        # 実行前にメッセージ送信する
        screen_sender $proc_screen "${BROADCAST_COMMAND} $3"
      fi
      while [ ${i} -ne 0 ]
      do
        if [ ${i} -eq ${interval} ]; then
          screen_sender $proc_screen "${BROADCAST_COMMAND} ${interval} $2"
        else
          if test `expr ${i} % 15` -eq 0 -o ${i} -le 10; then
            screen_sender $proc_screen "${BROADCAST_COMMAND} ${i} $2"
          fi
        fi
        i=$((${i} - 1))
        sleep 1
      done
    elif [ $PROC_COUNT == 0 ]; then
      OUT=`echo "[${YMD}] $proc_screen is empty process"`
      echo ${OUT}
    fi
  done
}

# stop/start機能 #########################################################################################
mc_check(){
  for proc_screen in ${!SERVER_PROPERTIES[@]};
  do
    screen_name="${SCREEN_PREFIX}-${proc_screen}"
    #監視するプロセスが何個起動しているかカウントする
    PROC_COUNT=`ps -ef | grep $screen_name | grep -v grep | wc -l`

    # 監視するプロセスが0個場合に、処理を分岐する
    if [ $PROC_COUNT = 0 ]; then
    # 0の場合は、サービスが停止しているので起動する
      echo "[${YMD}] [$proc_screen] Dead"
      mc_start

    elif [ $PROC_COUNT -ge 2 ]; then
    # 1以上の場合は、サービスが過剰に起動しているので再起動する
      echo "[${YMD}] [$proc_screen] Over Running"
      # カウントダウン後 Stop / Start を行う
      mc_restart 10 "§cプロセス異常を検知しました。" &
      wait
    else
    # サービス起動中
      echo "[${YMD}] [$proc_screen] Alive"
    fi
  done
  # echo -1000 > "/proc/`pidof java`/oom_score_adj"
  # echo $(ps -el | grep $(ps -el | grep SCREEN_SESSION_PID | grep bash | awk '{print $4}') | grep -v bash | awk '{print $4}')
}


# 起動処理 #################################################################################
mc_start(){
  jobsCron true
  for proc_screen in ${!SERVER_PROPERTIES[@]};
  do
    start "${proc_screen}" "${SERVER_PROPERTIES[$proc_screen]}"
  done
}

# 停止処理 #################################################################################
mc_stop(){
  jobsCron false
  sendMessage="秒後に停止します。"
  initMessage=""
  if [ -n "$2" ]; then
    sendMessage="$2"
  fi

  if [ -n "$3" ]; then
    initMessage="$3"
  fi

  count_wait "$1" "${sendMessage}" "${initMessage}"
  for proc_screen in ${!SERVER_PROPERTIES[@]};
  do
    stop $proc_screen
  done
}

# 再起動処理 #################################################################################
mc_restart(){
  sendMessage="秒後に再起動します。"

  if [ -n "$2" ]; then
    sendMessage="$2"
  fi
  mc_stop "$1" "${sendMessage}" "$3"
  sleep 3
  mc_start
}

# バックアップ処理 #################################################################################
mc_backup_world() {
for proc_screen in ${!SERVER_PROPERTIES[@]};
  do
    screen_name="${SCREEN_PREFIX}-${proc_screen}"
    PROC_COUNT=`ps -ef | grep $screen_name | grep -v grep | wc -l`
    if [ $PROC_COUNT = 0 ]; then
      #TODO Make it possible to take backups even when the server is not running.
      echo "[${YMD}] The server must be running for the backup to take place. "
    else
        screen_sender $proc_screen "${BROADCAST_COMMAND} §9Auto Backup Start"
        screen_sender $proc_screen "save-all"
        screen_sender $proc_screen "save-off"

        TARGET_DIR=${SERVER_PROPERTIES[$proc_screen]}
        MC_VER=`find "${TARGET_DIR}/" -maxdepth 1 -type f -name "spigot*.jar" | gawk -F/ '{print $NF}' | tr -cd '0123456789\n.' | awk '{print substr($0, 1, length($0)-1)}'`
        # MC_VER=`find "${TARGET_DIR}/" -maxdepth 1 -type f -name "spigot*.jar" | gawk -F/ '{print $NF}' | tr -cd '0123456789\n.' | awk '{ $a = substr($0, 2); sub(/.$/,"",$a); print $a }'`
        # cd $TARGET_DIR
        SERVER_NAME_GET_CMD="echo "${proc_screen}" | sed 's/${SCREEN_PREFIX}-//g'"
        MC_SERVER_NAME=$(eval "${SERVER_NAME_GET_CMD}")
        MC_BACKUP_WORLD_BASE=$(date '+%Y-%m-%d')
        MC_BACKUP_FILE="$(date '+h%H')-${MC_VER}"
        BASE_DIR="${MC_BACKUP_DIR_BASE%/}"
        for world in ${TARGET_WORLDS[@]};
        do
          BACKUP_TO="${BASE_DIR}/${MC_SERVER_NAME}/${MC_BACKUP_WORLD_BASE}/${MC_BACKUP_FILE}"
          mkdir -p $BACKUP_TO
          ZIP_FILE_NAME="${MC_SERVER_NAME}_${world}"
          ARC_FILE="${BACKUP_TO}/${ZIP_FILE_NAME}"
          TARGET="${TARGET_DIR}/${world}"
          if [ -e ${TARGET} ]; then
            # echo "zip -r ${ARC_FILE} ${TARGET} 1>/dev/null"
            # (cd ${TARGET_DIR}/ && zip -r ${ZIP_FILE_NAME} ${world} && mv ${ZIP_FILE_NAME} ${BACKUP_TO} --force) 1>/dev/null
            # UnArchives Command ( pv data.tar | tar xf - )
            (cd ${TARGET_DIR}/ && tar cf - ${world}/ | pv -s $(du -sb ${world} | awk '{print $1}') | bzip2 > "${ZIP_FILE_NAME}.tar.bz2" && mv "${ZIP_FILE_NAME}.tar.bz2" ${BACKUP_TO} --force)
    #        screen_sender $proc_screen "${BROADCAST_COMMAND} §aBackup Success ${ARC_FILE}"
            echo "[${YMD}] Backup Success ${ARC_FILE}"
            echo "${BACKUP_TO}/${ZIP_FILE_NAME}.tar.bz2"
          fi
      done
      screen_sender $proc_screen "save-on"
      screen_sender $proc_screen "${BROADCAST_COMMAND} §9Backup Complete"
      echo "[${YMD}] Backup Complete"
      find ${BASE_DIR}/${MC_SERVER_NAME} -name '*.tar.bz2' -mtime +${BACKUP_LEAVE_DAYS} -delete
    fi
  done
}

# CronJob設定 #################################################################################
jobsCron(){
  # スクリプト用のCronJobを設定する TrueならばInstall処理を行う
  isInstall=$1
#  CRON_PATH="/var/spool/cron/${RUN_USER}"
  CRON_PATH="/var/spool/cron/root"
  LOG_FILE_NAME="\`date +\%Y-\%m-\%d\`_healthcheck.log"

  EXEC_SHELL="/bin/sh ${SCRIPT_DIR}/${ME_FILE}"
  OUTPUT_LOG="${LOG_DIR}${LOG_FILE_NAME} 2>&1"

  CRON_TAG="### Minecraft HealthCheck Version: $VERSION Cron ${ME_FILE} ###"
  BACKUP_CRON="0 * * * * ${EXEC_SHELL} backup >> ${OUTPUT_LOG}"
  CHECK_CRON="* * * * * ${EXEC_SHELL} check >> ${OUTPUT_LOG}"
  LOG_ROTATE="@daily find ${LOG_DIR}/ -name '*.log' -mtime +${LOG_LEAVE_DAYS} -delete"

  SED_CMD="sed -i -e '/${ME_FILE}/d' ${CRON_PATH}"
  eval "${SED_CMD}"

  if "${isInstall}"; then
    echo "${CRON_TAG}" >> ${CRON_PATH}
    echo "${BACKUP_CRON}" >> ${CRON_PATH}
    echo "${CHECK_CRON}" >> ${CRON_PATH}
    echo "[${YMD}] cron jobs append"
  else
      echo "[${YMD}] cron jobs delete"
  fi

  systemctl restart crond
}

# 処理分岐 #########################################################################################
if [ $# = 0 ]; then
    echo "[${YMD}] No argument is specified."
    exit 1
else
  case "$1" in
      start)
        mc_start
        exit 0
        ;;
      stop)
        mc_stop "$2" "$3" "$4"
        exit 0
        ;;
      restart)
        mc_restart "$2" "$3" "$4"
        exit 0
          ;;
      check)
        mc_check
        exit 0
          ;;
      backup)
        mc_backup_world
        exit 0
        ;;
      install)
        jobsCron true
        exit 0
        ;;
      uninstall)
        jobsCron false
        exit 0
        ;;
      help)
          echo ""
          msg=$(sed -rn '/^# Usage/,${/^#/!q;s/^# ?//;p}' "$SCRIPT_PATH")
          eval $'cat <<__END__\n'"$msg"$'\n__END__\n'
          echo ""
        ;;
      version)
          msg=$(sed -rn '/^# Version/,${/^#/!q;s/^# ?//;p}' "$SCRIPT_PATH")
          eval $'cat <<__END__\n'"$msg"$'\n__END__\n'
        ;;
      *)
        echo "[${YMD}] command not found $1"
        exit 0
  esac
fi
#    （＼　　　_
#　　 ｜ )　　 ／ )
#　　 / ｜　　(　/
#　　/　/　　 ｜｜
#　 /　｜　　 ｜｜
#　 ＼　＼　　/ ｜
#　　 ＼　＼／　/
#　　＿｜　　　/＿＿
#　　 ￣三三三二￣
