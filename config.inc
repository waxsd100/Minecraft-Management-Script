# Server 設定

# Server ディレクトリを設定する
SERVER_PROPERTIES=(["minecraft"]="/opt/minecraft/server/")

# 実行コマンドを定義
EXEC_COMMAND=(["minecraft"]="java -Xms7G -Xmx14G -jar spigot-*.jar nogui")

# BACKUP TARGET World
TARGET_WORLDS=("world" "world_nether" "world_the_end")

# 定数定義

# 実行ユーザ定義
readonly RUN_USER="minecraft"

# ScreenNameのプレフィックス
SCREEN_PREFIX="minecraft"

# 停止カウントダウン秒数
readonly STOP_INTERVAL=30

# 停止コマンド
readonly STOP_COMMAND="stop"

# ブロードキャストコマンド
readonly BROADCAST_COMMAND="say"

# バックアップ設定
readonly MC_BACKUP_DIR_BASE="/mnt/google-drive/Backups/Minecraft/"

# ログ保存期間
readonly LOG_LEAVE_DAYS=14

# Backup保存期間
readonly BACKUP_LEAVE_DAYS=7

# Discord WebHook URL
readonly DISCORD_WEB_HOOK_URL="https://discordapp.com/api/webhooks/###########/#########"

# Discord通知フラグ
readonly DISCORD_NOTICE=false

# Version: 0.0.3
