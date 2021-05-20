# minecraft サーバーヘルスチェックと管理スクリプト

BungeeCord版を見る   
https://gist.github.com/waxsd100/1d80bc70a07ebbaeccaa5bd98ed99168

0. Minecraft サーバーインストール
1. `yum install screen jq pv` を実行する。
2. config.inc ファイルを編集する（同じディレクトリに置く）。
```
# config.inc

# サーバー名とサーバーパスの設定
SERVER_PROPERTIES=(
 ["サーバネーム 01"]="サーバーディレクトリ"
 ["サーバネーム 02"]="サーバーディレクトリ"
)

# Minecraft Server Start Commandを設定します。
EXEC_COMMAND=(["サーバネーム 01"]="java -Xms7G -Xmx14G -jar spigot-*.jar nogui")

# バックアップするWorldフォルダを設定します。(もしかしたら、World以外でも可能かもしれません。)
TARGET_WORLDS=("world" "world_nether" "world_the_end")


```
4. `crontab -e` を追加します (通常は自動的に設定されます)。
```
# HealthCheck 
* * * for i in `seq 0 10 59`;do (sleep ${i}; /bin/sh /var/minecraft/healthcheck/health.sh check >> /var/minecraft/healthcheck/log/`date +\%Y-%m-%d_healthcheck`.log 2>&1) & done;
@daily find /var/minecraft/healthcheck/log/ -name '*.log' -mtime +30 -delete
```
10秒に1回実行されます。
実行ファイルの場所などは必要に応じて変更してください。


5. 高度な設定
   以下の設定を変更したい場合は、config.incの変数を変更してください。

Screenを実行するユーザーを変更します。
```
RUN_USER="minecraft"
```
カウントダウンタイマーが止まるまで変更します。
```
STOP_INTERVAL=60
```
停止時にScreenSessionに送信するコマンドを設定する。
```
STOP_COMMAND="stop"
```

# 使用コマンド

```diff
- 注 root ユーザで実行する必要があります。
```

使い方を説明します。Minecraft ヘルスチェック＆バックアップスクリプト [スクリプトモード] [オプション]

予期せぬ結果が発生する可能性があります。
実行する前に必ず Config ファイルの設定を行ってください。
オプションは

start)    
    MinecraftサーバーのスタートとCronJobの追加  
stop)    
    Minecraftサーバーの停止とCronJobの削除  
restart)    
    Minecraft サーバーの再起動  
check)    
    Minecraft サーバーの開始または停止のチェック  
backup)    
    Minecraft サーバーのバックアップ

引数は
stop / restart [stop interval] [message]

           [stop interval] 停止するまでの秒数を指定します。 
                          (空欄の場合は、デフォルトの設定が使用されます)。 

           [message] 停止する前にサーバーにブロードキャストメッセージを送信します。 



## ライセンス
これらのコードはMITライセンスで公開されています。LICENSEをご参照ください。
