import subprocess
import random
import time
import json
from datetime import datetime
import logging
import socket

# Configuration constants
DIR_PATH_KAFKA = "/usr/local/kafka/bin/kafka-console-producer.sh"
TOPIC = "advanced-node-01"
KAFKA_PORT = 9092

server_list = ["192.168.100.10", "192.168.100.11", "192.168.100.12"]
uri_list = ["/advanced-node-01/api/post-users", "/advanced-node-01/api/get-users"]
method_list = ["GET", "POST"]
bank_list = ["VIETTINBANK", "VIETCOMBANK", "BIDV", "SHINHAN BANK", "MOMO"]
user_list = ["0866988154", "0866988155"]

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

def get_ip():
    try:
        ip = socket.gethostbyname(socket.gethostname())
        return ip
    except socket.error as e:
        logging.error("Unable to get IP address: %s", e)
        raise

IP_PORT_KAFKA = f"{get_ip()}:{KAFKA_PORT}"

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
    
    try:
        process = subprocess.Popen(command, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        stdout, stderr = process.communicate(input=json_message.encode())
        if process.returncode != 0:
            logging.error("Error sending message to Kafka: %s", stderr.decode())
            return False
        return True
    except Exception as e:
        logging.error("Exception occurred while sending message: %s", e)
        return False

def main():
    if not subprocess.call(["test", "-x", DIR_PATH_KAFKA]) == 0:
        logging.error('Kafka producer script not found or not executable at %s. Exiting...', DIR_PATH_KAFKA)
        exit(1)

    try:
        while True:
            if not send_message():
                exit(1)
            time.sleep(1)
    except KeyboardInterrupt:
        logging.info("Interrupted by user.")
    except Exception as e:
        logging.error("An unexpected error occurred: %s", e)

if __name__ == "__main__":
    main()
