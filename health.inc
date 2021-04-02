# 監視するプロセス名を定義する
WATCH_PROCESS=(["uro"]="/var/minecraft/server/uro_1-16/")

# 実行コマンドを定義
EXEC_COMMAND=(["uro"]="java -Xms7G -Xmx14G -jar spigot-*.jar nogui")

# BACKUP TARGET World
TARGET_WORLDS=("world" "world_nether" "world_the_end")

# Version: 0.0.2