#!/bin/sh

if [ ! -f /app/thumbor.conf ]; then
  envtpl /app/thumbor.conf.tpl --allow-missing --keep-template
fi

# If log level is defined we configure it, else use default log_level = info
if [ -n "$LOG_LEVEL" ]; then
    LOG_PARAMETER="-l $LOG_LEVEL"
fi

# Default port 80 and 1 process when not defined (an empty value is kept as-is)
THUMBOR_PORT="${THUMBOR_PORT-80}"
THUMBOR_NUM_PROCESSES="${THUMBOR_NUM_PROCESSES-1}"

if [ "$1" = 'thumbor' ]; then
    echo "---> Starting thumbor with ${THUMBOR_NUM_PROCESSES:-1} processes..."
    exec thumbor --port="$THUMBOR_PORT" --conf=/app/thumbor.conf $LOG_PARAMETERS --processes="${THUMBOR_NUM_PROCESSES:-1}" --log-level=warning --app tc_core.app.App
fi

exec "$@"
