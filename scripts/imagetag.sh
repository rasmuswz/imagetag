#!/bin/bash
ImagePath=${2}

function start() {
  goimagetag/bin/main ./build/web ${ImagePath} > imagetag.log 2>&1 &
  disown $!
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
    stop
    start
    ;;
    *)
    echo "script supports start, stop and restart";
    ;;
esac