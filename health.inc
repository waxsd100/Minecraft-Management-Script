# Server ディレクトリを設定する
SERVER_PROPERTIES=(["uro"]="/var/minecraft/server/uro_1-16/")

# 実行コマンドを定義
EXEC_COMMAND=(["uro"]="java -Xms7G -Xmx14G -jar spigot-*.jar nogui")

# BACKUP TARGET World
TARGET_WORLDS=("world" "world_nether" "world_the_end")

# Version: 0.0.2