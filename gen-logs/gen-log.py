import subprocess
import random
import time
import json
from datetime import datetime

DIR_PATH_KAFKA = "/usr/local/kafka/bin/kafka-console-producer.sh"
TOPIC = "advanced-node-01"
IP_PORT_KAFKA = subprocess.getoutput("hostname -I").split()[0] + ":9092"

server_list = ["192.168.100.10", "192.168.100.11", "192.168.100.12"]
uri_list = ["/advanced-node-01/api/post-users", "/advanced-node-01/api/get-users"]
method_list = ["GET", "POST"]
bank_list = ["VIETTINBANK", "VIETCOMBANK", "BIDV", "SHINHAN BANK", "MOMO"]
user_list = ["0866988154", "0866988155"]

def send_message():
    datetime_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    server = random.choice(server_list)
    uri = random.choice(uri_list)
    method = random.choice(method_list)
    bank = random.choice(bank_list)
    user = random.choice(user_list)
    process_time = random.randint(0, 999)
    request_id = random.randint(0, 9999)
    message = {
        "timestamp": datetime_str,
        "server": server,
        "service_name": "advanced-node-01-service",
        "application_name": "advanced-node-01-system",
        "response": "resp_to_sdk",
        "uri": uri,
        "method": method,
        "http_status": "200",
        "code": "0",
        "bankCode": bank,
        "request_id": str(request_id),
        "process_time": str(process_time),
        "user": user,
        "channel": "Sdk",
        "push_to": "NAGIOS_MONITOR"
    }
    json_message = json.dumps(message)
    command = [DIR_PATH_KAFKA, "--topic", TOPIC, "--bootstrap-server", IP_PORT_KAFKA]
    process = subprocess.Popen(command, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    stdout, stderr = process.communicate(input=json_message.encode())
    if process.returncode != 0:
        print("Error sending message to Kafka. Exiting...")
        print(stderr.decode())
        return False
    return True

def main():
    if not subprocess.call(["test", "-x", DIR_PATH_KAFKA]) == 0:
        print(f'Kafka producer script not found or not executable at {DIR_PATH_KAFKA}. Exiting...')
        exit(1)

    try:
        while True:
            if not send_message():
                exit(1)
            time.sleep(1)
    except KeyboardInterrupt:
        print("Interrupted by user.")

if __name__ == "__main__":
    main()
