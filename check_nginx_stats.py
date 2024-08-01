#!/usr/bin/env python3

import argparse
import json
import re
import sqlite3
import sys
import time
from typing import Dict, Tuple, Optional

import requests
from requests.exceptions import RequestException

# Nagios return codes
OK = 0
WARNING = 1
CRITICAL = 2
UNKNOWN = 3

class NginxStatsPlugin:
    def __init__(self):
        self.args = self.parse_arguments()
        self.conn = self.setup_database()
        self.nginx_stats = {}

    def parse_arguments(self) -> argparse.Namespace:
        parser = argparse.ArgumentParser(description="Nagios Plugin to check Nginx stats")
        parser.add_argument('-H', '--host', required=True, help="Host to connect to")
        parser.add_argument('-P', '--port', type=int, default=80, help="Port to connect to")
        parser.add_argument('-u', '--url', required=True, help="Nginx Status URL")
        parser.add_argument('--ssl', action='store_true', help="Use HTTPS")
        parser.add_argument('--no-keepalives', action='store_true', help="Enable extra sanity check for Handled/Requests")
        parser.add_argument('-w', '--warning', help="Warning threshold for Active Connections (min:max)")
        parser.add_argument('-c', '--critical', help="Critical threshold for Active Connections (min:max)")
        parser.add_argument('-t', '--timeout', type=int, default=10, help="Timeout in seconds")
        parser.add_argument('-v', '--verbose', action='store_true', help="Verbose output")
        return parser.parse_args()

    def setup_database(self) -> sqlite3.Connection:
        db_file = f"/tmp/nginx_stats_{self.args.host}.db"
        conn = sqlite3.connect(db_file)
        cursor = conn.cursor()
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS nginx_stats (
                timestamp INTEGER PRIMARY KEY,
                active INTEGER,
                accepted INTEGER,
                handled INTEGER,
                requests INTEGER,
                reading INTEGER,
                writing INTEGER,
                waiting INTEGER
            )
        ''')
        conn.commit()
        return conn

    def fetch_nginx_stats(self) -> Dict[str, int]:
        protocol = "https" if self.args.ssl else "http"
        url = f"{protocol}://{self.args.host}:{self.args.port}{self.args.url}"
        
        try:
            response = requests.get(url, timeout=self.args.timeout)
            response.raise_for_status()
        except RequestException as e:
            self.exit(CRITICAL, f"Error accessing Nginx status page: {str(e)}")

        content = response.text
        stats = {}
        
        match = re.search(r"Active connections:\s+(\d+)", content)
        if match:
            stats['active'] = int(match.group(1))
        
        match = re.search(r"(\d+)\s+(\d+)\s+(\d+)", content)
        if match:
            stats['accepted'] = int(match.group(1))
            stats['handled'] = int(match.group(2))
            stats['requests'] = int(match.group(3))
        
        match = re.search(r"Reading:\s+(\d+)\s+Writing:\s+(\d+)\s+Waiting:\s+(\d+)", content)
        if match:
            stats['reading'] = int(match.group(1))
            stats['writing'] = int(match.group(2))
            stats['waiting'] = int(match.group(3))
        
        if len(stats) != 7:
            self.exit(UNKNOWN, f"Failed to parse all Nginx stats from: {content}")
        
        return stats

    def perform_sanity_checks(self):
        if self.nginx_stats['accepted'] < self.nginx_stats['handled']:
            self.exit(CRITICAL, "Handled connection count > Accepted connection count")
        if self.args.no_keepalives and self.nginx_stats['handled'] < self.nginx_stats['requests']:
            self.exit(CRITICAL, "Request count > Handled connection count")

    def calculate_rates(self) -> Tuple[float, float]:
        cursor = self.conn.cursor()
        cursor.execute("SELECT * FROM nginx_stats ORDER BY timestamp DESC LIMIT 1")
        last_stats = cursor.fetchone()

        if not last_stats:
            return 0, 0

        now = int(time.time())
        time_diff = now - last_stats[0]
        
        if time_diff == 0:
            return 0, 0

        conns_rate = (self.nginx_stats['accepted'] - last_stats[2]) / time_diff
        reqs_rate = (self.nginx_stats['requests'] - last_stats[4]) / time_diff

        return conns_rate, reqs_rate

    def update_database(self):
        cursor = self.conn.cursor()
        now = int(time.time())
        cursor.execute('''
            INSERT INTO nginx_stats 
            (timestamp, active, accepted, handled, requests, reading, writing, waiting) 
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''', (now, self.nginx_stats['active'], self.nginx_stats['accepted'], 
              self.nginx_stats['handled'], self.nginx_stats['requests'], 
              self.nginx_stats['reading'], self.nginx_stats['writing'], 
              self.nginx_stats['waiting']))
        self.conn.commit()

    def check_thresholds(self, value: int, warning: Optional[str], critical: Optional[str]) -> Tuple[int, str]:
        if critical:
            try:
                crit_min, crit_max = map(int, critical.split(':'))
                if value < crit_min or value > crit_max:
                    return CRITICAL, f"CRITICAL - Active connections: {value}"
            except ValueError:
                self.exit(UNKNOWN, f"Invalid critical threshold format: {critical}")

        if warning:
            try:
                warn_min, warn_max = map(int, warning.split(':'))
                if value < warn_min or value > warn_max:
                    return WARNING, f"WARNING - Active connections: {value}"
            except ValueError:
                self.exit(UNKNOWN, f"Invalid warning threshold format: {warning}")

        return OK, f"OK - Active connections: {value}"

    def generate_output(self, conns_rate: float, reqs_rate: float) -> Tuple[int, str]:
        status, message = self.check_thresholds(self.nginx_stats['active'], self.args.warning, self.args.critical)

        output = (f"{message}, "
                  f"Connections/sec: {conns_rate:.2f}, "
                  f"Requests/sec: {reqs_rate:.2f}, "
                  f"Reading: {self.nginx_stats['reading']}, "
                  f"Writing: {self.nginx_stats['writing']}, "
                  f"Waiting: {self.nginx_stats['waiting']}")

        perfdata = (f"'Active connections'={self.nginx_stats['active']};"
                    f"{self.args.warning or ''};"
                    f"{self.args.critical or ''};"
                    f"0; "
                    f"'Connections/sec'={conns_rate:.2f} "
                    f"'Requests/sec'={reqs_rate:.2f} "
                    f"'Reading'={self.nginx_stats['reading']} "
                    f"'Writing'={self.nginx_stats['writing']} "
                    f"'Waiting'={self.nginx_stats['waiting']} "
                    f"'Accepted'={self.nginx_stats['accepted']} "
                    f"'Handled'={self.nginx_stats['handled']} "
                    f"'Requests'={self.nginx_stats['requests']}")

        return status, f"{output} | {perfdata}"

    def run(self):
        self.nginx_stats = self.fetch_nginx_stats()
        self.perform_sanity_checks()
        conns_rate, reqs_rate = self.calculate_rates()
        self.update_database()
        status, output = self.generate_output(conns_rate, reqs_rate)
        self.exit(status, output)

    def exit(self, status: int, message: str):
        if self.args.verbose:
            print(f"Verbose: {json.dumps(self.nginx_stats, indent=2)}")
        print(message)
        sys.exit(status)

if __name__ == "__main__":
    NginxStatsPlugin().run()
