#!/bin/bash

# 并发量
limit=5
# 描述符
pipe_fd=9
# 管道名
pipe_name="/tmp/$$.pipe"

# 设置并发量
# $1 并发量，默认 5，取值范围 (0,`ulimit -u`)
function _limit_concurrency() {
  [[ ! $1 =~ ^[0-9]+$ ]] && return
  test $1 -ne 0 -a $1 -lt $(ulimit -u) && limit=$1
}

# 创建命名管道，模拟令牌桶
function _create_pipe() {
  mkfifo $pipe_name
  eval exec "$pipe_fd<>$pipe_name"
  rm -f $pipe_name
}

# 关闭管道读写
function _close_pipe() {
  eval exec "$pipe_fd>&-"
  eval exec "$pipe_fd<&-"
}

# 创建令牌桶
function _create_bucket() {
  for ((i=0; i<$limit; i++)); do
    _post_token
  done
}

# 取出令牌
function _get_token() {
  read -u$pipe_fd
}

# 放回令牌
function _post_token() {
  echo >&$pipe_fd
}

# 并发初始化
function concurrent_init() {
  _limit_concurrency $1
  _create_pipe
  _create_bucket
}

# 并发执行
# $@ 并发任务
function concurrent_run() {
  task="$@"
  test -z "$task" && {
    echo "requires a command to run." && _close_pipe
    exit 1
  }
  # 取出令牌，如果数量不足，则阻塞等待
  _get_token
  {
    $task
    # 放回令牌，任务执行完成后，将令牌放回桶内
    _post_token
  }&
}

# 等待所有任务完成
function concurrent_wait() {
  wait
  _close_pipe
}
