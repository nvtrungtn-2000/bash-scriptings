#!/bin/bash

DIR_PATH_KAFKA="/usr/local/kafka/bin/kafka-console-producer.sh"
TOPIC="advanced-node-01"
IP_PORT_KAFKA="$(hostname -I | awk '{print $1}'):9092"

server_list=("192.168.100.10" "192.168.100.11" "192.168.100.12")
uri_list=("/advanced-node-01/api/post-users" "/advanced-node-01/api/get-users")
method_list=("GET" "POST")
bank_list=("VIETTINBANK" "VIETCOMBANK" "BIDV" "SHINHAN BANK" "MOMO")
user_list=("0866988154" "0866988155")

send_message() {
  local datetime server uri method bank user process_time request_id message

  datetime=$(date +"%Y-%m-%d %H:%M:%S")
  server=${server_list[RANDOM % ${#server_list[@]}]}
  uri=${uri_list[RANDOM % ${#uri_list[@]}]}
  method=${method_list[RANDOM % ${#method_list[@]}]}
  bank=${bank_list[RANDOM % ${#bank_list[@]}]}
  user=${user_list[RANDOM % ${#user_list[@]}]}
  process_time=$((RANDOM % 1000))
  request_id=$((RANDOM % 10000))
  message=$(jq -n \
    --arg timestamp "$datetime" \
    --arg server "$server" \
    --arg uri "$uri" \
    --arg method "$method" \
    --arg bankCode "$bank" \
    --arg request_id "$request_id" \
    --arg process_time "$process_time" \
    --arg user "$user" \
    '{
      timestamp: $timestamp,
      server: $server,
      service_name: "advanced-node-01-service",
      application_name: "advanced-node-01-system",
      response: "resp_to_sdk",
      uri: $uri,
      method: $method,
      http_status: "200",
      code: "0",
      bankCode: $bankCode,
      request_id: $request_id,
      process_time: $process_time,
      user: $user,
      channel: "Sdk",
      push_to: "NAGIOS_MONITOR"
    }')

  if ! echo "$message" | "$DIR_PATH_KAFKA" --topic "$TOPIC" --bootstrap-server "$IP_PORT_KAFKA"; then
    printf 'Error sending message to Kafka. Exiting...\n' >&2
    return 1
  fi
}

main() {
  # Check if Kafka producer script exists
  if [[ ! -x "$DIR_PATH_KAFKA" ]]; then
    printf 'Kafka producer script not found or not executable at %s. Exiting...\n' "$DIR_PATH_KAFKA" >&2
    exit 1
  fi

  while true; do
    if ! send_message; then
      exit 1
    fi
    sleep 1
  done
}

main
