#!/bin/bash
# mysql -h172.18.46.93 -uzje -sN -e "select table_name from information_schema.tables where table_schema='zjy_volunteer_police'"
# mysqldump -h172.18.46.93 -uzje zjy_volunteer_police 表名> 导出的文件名

# 设置环境变量，就不需要在命令中传入密码，屏蔽一个 warning（命令行中包含密码警告）
export MYSQL_PWD=zjEYjCjRds21

# 导出的 sql 存放地址
path=$(pwd)/sql.d

host=172.18.46.93
user=zje
db=zjy_volunteer_police

# 执行 sql 语句，-s 不显示边框/分隔符，-N 不显示列名，-e 执行一个命令
mysql_exec="mysql -h $host -u $user -sN -e"

# 执行 dump 语句，-set-gtid-purged=off 屏蔽一个 warning（导出后再导入到新库，无法保证全局事物唯一性警告）
mysqldump_exec="mysqldump -h $host -u $user --set-gtid-purged=off"

# 数据表查询 sql
tables_sql="select table_name from information_schema.tables where table_schema='$db'"

function dump() {
  eval "$mysqldump_exec $db $1 > $path/$1.sql"
  printf '%-32s %s\n' $1 100%
}

test ! -d $path && mkdir $path

. ./concurrent.sh
concurrent_init 10
# 查询数据库包含的数据表，并排除不需要导出的表
for table in $(eval "$mysql_exec \"$tables_sql\"" | sed 's/ /\'$'\n/g' | grep -v his); do
  concurrent_run dump $table
done
concurrent_wait

tar -zcf $db.tar.gz -C $path $(ls $path) && echo OK.
