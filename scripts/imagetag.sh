#!/bin/bash
ImagePath=${2}

function start() {
  goimagetag/bin/main ./build/web ${ImagePath}
}

function stop() {
    pgrep main | xargs kill -9
}

case ${1} in
    start)
    start
    ;;
    stop)
    stop
    ;;
    restart)
    start
    stop
    ;;
    *)
    echo "script supports start, stop and restart";
    ;;
esac