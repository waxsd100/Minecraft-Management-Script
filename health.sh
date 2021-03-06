#! /bin/bash
exec {lock_fd}< "$0"
flock --nonblock ${lock_fd} || echo "Duplicate startup Error"; exit 0
declare -A WATCH_PROCESS;
cd "${0%/*}" > /dev/null 2>&1 || :

readonly ME_FILE=$(basename "$0")
readonly SCRIPT_DIR=$(cd $(dirname "$0") || exit; pwd)
readonly LOG_DIR="${SCRIPT_DIR}/log/"
readonly LOCAL_IP=$(ip -f inet -o addr show eth0|cut -d\  -f 7 | cut -d/ -f 1)

# 表示設定
readonly RESET=$'\e[0m'
readonly BOLD=$'\e[1m'
readonly RED=$'\e[1;31m'
readonly GREEN=$'\e[1;32m'
readonly YMD=$(date '+%y/%m/%d %H:%M:%S')

# 定数定義

# ログ保存期間
readonly LOG_LEAVE_DAYS=14

# 実行ユーザ定義
readonly RUN_USER="root"

# 停止カウントダウン秒数
readonly STOP_INTERVAL=30

# 停止コマンド
readonly STOP_COMMAND="stop"

# ブロードキャストコマンド
readonly BROADCAST_COMMAND="say"

# バックアップ設定
readonly MC_BACKUP_DIR_BASE="/mnt/google-drive/TUSB/Server-Storage/"

# Discord WebHook URL
readonly DISCORD_WEB_HOOK_URL="https://discordapp.com/api/webhooks/###########/#########"

# Discord通知フラグ
readonly DISCORD_NOTICE=false

# Import
. ./health.inc
source ./exception.sm

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
  ME=$(whoami)
    if [ "${ME}" == ${RUN_USER} ] ; then
        bash -c "$1"
    else
        su - ${RUN_USER} -c "$1"
    fi
}

screen_shutdown(){
  # $1 screenName
  # $2 execCommand

  for pid in $(screen -list | grep "$1" | cut -f1 -d'.' | sed 's/\W//g')
  do
    echo "${pid} killed"
    kill "${pid}"
  done
}


screen_sender(){
  # $1 screenName
  # $2 execCommand

  for pid in $(screen -list | grep "$1" | cut -f1 -d'.' | sed 's/\W//g')
  do
    SEND_SCREEN="screen -p 0 -S ${pid}.$1 -X eval"
    echo "[${YMD}] ${pid} $1 > $2"
    as_user "${SEND_SCREEN} 'stuff \"$2\"\015'"
  done
}

start(){
  # $1 screenName
  # $2 shellCommand
  PROC_COUNT=$(ps -ef | grep "$proc_screen" | grep -v grep | wc -l)
  if [ "$PROC_COUNT" = 0 ]; then
    OUT=$(sh "$2" && echo "[${YMD}] $1 Up" || echo "[${YMD}] $1 Up Oops")
    send_discord "$1 Server Start" "${OUT}" "${LOCAL_IP}" "0x2ECC71"
  else
    OUT=$(echo "[${YMD}] $1 Up Oops")
  fi
  echo "${OUT}"
}

stop(){
  # $1 screenName
  # $2 ScreenCommand
  screen_sender "$1" $STOP_COMMAND
  if [ $? = 0 ]; then
    OUT=$(echo "[${YMD}] $1 Down")
  else
    OUT=$(echo "[${YMD}] $1 Down Oops")
    screen_shutdown "$1"
  fi

  send_discord "$1 Server Stop" "${OUT}" "${LOCAL_IP}" "0xE91E63"

}

count_wait(){
  # $1 count wait time(sec)
  # $2 sen server message
  # $3 init sercer message
  if [ -n "$1" ]; then
    interval=$(expr "$1")
  else
    interval=$STOP_INTERVAL
  fi

  for proc_screen in ${!WATCH_PROCESS[@]};
    do
    PROC_COUNT=$(ps -ef | grep "$proc_screen" | grep -v grep | wc -l)
    if [ "$PROC_COUNT" != 0 ]; then
      i=${interval}
      if [ -n "$3" ]; then
        screen_sender "$proc_screen" "${BROADCAST_COMMAND} $3"
      fi
      while [ ${i} -ne 0 ]
      do
        if [ ${i} -eq ${interval} ]; then
          screen_sender "$proc_screen" "${BROADCAST_COMMAND} ${interval} $2"
        else
          if test $(expr ${i} % 15) -eq 0 -o ${i} -le 10; then
            screen_sender "$proc_screen" "${BROADCAST_COMMAND} ${i} $2"
          fi
        fi
        i=$((${i} - 1))
        sleep 1
      done
    elif [ "$PROC_COUNT" == 0 ]; then
      OUT=$(echo "[${YMD}] $proc_screen empty process")
      echo "${OUT}"
    fi
  done
}

# stop/start機能 #########################################################################################
mc_check(){
  for proc_screen in ${!WATCH_PROCESS[@]};
  do
    #監視するプロセスが何個起動しているかカウントする
    PROC_COUNT=$(ps -ef | grep "$proc_screen" | grep -v grep | wc -l)

    # 監視するプロセスが0個場合に、処理を分岐する
    if [ "$PROC_COUNT" = 0 ]; then
    # 0の場合は、サービスが停止しているので起動する
      echo "[${YMD}] $proc_screen Dead"
      mc_start

    elif [ "$PROC_COUNT" -ge 2 ]; then
    # 1以上の場合は、サービスが過剰に起動しているので再起動する
      echo "[${YMD}] $proc_screen Over Running"
      # カウントダウン後 Stop / Start を行う
      mc_restart 10 "§cプロセス異常を検知しました。" &
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
  jobsCron true
  for proc_screen in ${!WATCH_PROCESS[@]};
  do
    start "$proc_screen" "${WATCH_PROCESS[$proc_screen]}"
  done
}

# 停止処理 #################################################################################
mc_stop(){
  jobsCron false
  count_wait "$1" "秒後に停止します。" "$2"
  for proc_screen in ${!WATCH_PROCESS[@]};
  do
    stop "$proc_screen"
  done
}

# 再起動処理 #################################################################################
mc_restart(){
  count_wait "$1" "秒後に再起動します。" "$2"
  mc_stop
  sleep 3
  mc_start
}

# バックアップ処理 #################################################################################
mc_backup_world() {
for proc_screen in ${!WATCH_PROCESS[@]};
  do
    screen_sender "$proc_screen" "${BROADCAST_COMMAND} §9Auto Backup Start"
    screen_sender "$proc_screen" "save-all"
    screen_sender "$proc_screen" "save-off"
    MC_SERVER_NAME=$(echo "${proc_screen}" | sed 's/minecraft-//g')
    MC_BACKUP_FILE=$(date '+%Y-%m-%d_h%H')

    TARGET_DIR=$(dirname "${WATCH_PROCESS[$proc_screen]}")
    MC_VER=$(find "${TARGET_DIR}/" -maxdepth 1 -type f -name "spigot*.jar" | gawk -F/ '{print $NF}' | tr -cd '0123456789\n.' | awk '{print substr($0, 1, length($0)-1)}')
    # MC_VER=`find "${TARGET_DIR}/" -maxdepth 1 -type f -name "spigot*.jar" | gawk -F/ '{print $NF}' | tr -cd '0123456789\n.' | awk '{ $a = substr($0, 2); sub(/.$/,"",$a); print $a }'`
    # cd $TARGET_DIR
    for world in ${TARGET_WORLDS[@]};
    do
      BACKUP_TO="${MC_BACKUP_DIR_BASE}${MC_SERVER_NAME}/${MC_VER}/${MC_BACKUP_FILE}"
      mkdir -p "$BACKUP_TO"
      ZIP_FILE_NAME="${MC_SERVER_NAME}_${world}.zip"
      ARC_FILE="${BACKUP_TO}/${ZIP_FILE_NAME}"
      TARGET="${TARGET_DIR}/${world}"
      if [ -e "${TARGET}" ]; then
        # echo "zip -r ${ARC_FILE} ${TARGET} 1>/dev/null"
        (cd "${TARGET_DIR}"/ && zip -r "${ZIP_FILE_NAME}" "${world}" && mv "${ZIP_FILE_NAME}" "${BACKUP_TO}" --force) 1>/dev/null
        screen_sender "$proc_screen" "${BROADCAST_COMMAND} §aBackup Success ${ARC_FILE}"
        echo "[${YMD}] Backup Success ${ARC_FILE}"
      fi
  done
  screen_sender "$proc_screen" "save-on"

  find ${MC_BACKUP_DIR_BASE} -name '*.zip' -mtime +3 -delete
  screen_sender "$proc_screen" "${BROADCAST_COMMAND} §9Backup Complete"
  echo "[${YMD}] Backup Complete"
  done
}

# CronJob設定 #################################################################################
jobsCron(){
  # スクリプト用のCronJobを設定する TrueならばInstall処理を行う
  isInstall=$1

  CRON_PATH="/var/spool/cron/${RUN_USER}"
  LOG_FILE_NAME="\`date +\%Y-\%m-\%d\`_healthcheck.log"

  EXEC_SHELL="/bin/sh ${SCRIPT_DIR}/${ME_FILE}"
  OUTPUT_LOG="${LOG_DIR}${LOG_FILE_NAME} 2>&1"

  CRON_TAG="### Minecraft HealthCheck Cron ${ME_FILE} ###"
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
        mc_start "$2"
        exit 0
        ;;
      stop)
        mc_stop "$2" "$3"
        exit 0
        ;;
      restart)
        mc_restart "$2" "$3"
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
fi
exit 0
