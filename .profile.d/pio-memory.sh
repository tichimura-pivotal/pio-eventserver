#!/usr/bin/env bash

# Fail immediately on non-zero exit code.
set -e
# Fail immediately on non-zero exit code within a pipeline.
set -o pipefail
# Fail on undeclared variables.
set -u
# Debug, echo every command
#set -x

function already_has_memory_opts() {
  echo ${@:-} | grep --extended-regexp '(--executor-memory|--driver-memory)'
}

limit=$(ulimit -u)
case $limit in
256)   # 512MB (Free, Hobby, Standard-1X)
  default_spark_opts="--executor-memory 256m --driver-memory 256m"
  ;;
512)   # 1024MB (Standard-2X, Private-S)
  default_spark_opts="--executor-memory 512m --driver-memory 512m"
  ;;
16384) # 2560MB (Performance-M, Private-M)
  default_spark_opts="--executor-memory 1536m --driver-memory 1024m"
  ;;
32768) # 14GB (Performance-L, Private-L)
  default_spark_opts="--executor-memory 10g --driver-memory 4g"
  ;;
*)
  default_spark_opts="--executor-memory 256m --driver-memory 256m"
  ;;
esac


PIO_SPARK_OPTS=${PIO_SPARK_OPTS:-}

if [ ! "$(already_has_memory_opts $PIO_SPARK_OPTS)" ]
then
  export PIO_SPARK_OPTS="$default_spark_opts $PIO_SPARK_OPTS"
  echo "Autoset Spark memory params for web process: $PIO_SPARK_OPTS"
fi

PIO_TRAIN_SPARK_OPTS=${PIO_TRAIN_SPARK_OPTS:-}

if [ ! "$(already_has_memory_opts $PIO_TRAIN_SPARK_OPTS)" ]
then
  export PIO_TRAIN_SPARK_OPTS="$default_spark_opts $PIO_TRAIN_SPARK_OPTS"
  echo "Autoset Spark memory params for training: $PIO_TRAIN_SPARK_OPTS"
fi
