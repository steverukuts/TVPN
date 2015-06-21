#!/usr/bin/env python
#
#   This script runs a web server, which when accessed will reset a timer.
#   If the web server is not accessed regularly, it will shut down the
#   instance.
#

import SimpleHTTPServer
import SocketServer
from multiprocessing import Process
from datetime import datetime, timedelta
import time
import sys
import os

shutdown_delta = timedelta(minutes=5)
shutdown_on = datetime.now() + shutdown_delta

def poll_timer():
    while True:
        if datetime.now() > shutdown_on:
            print "poll: Shutting down!"
            os.system("halt")
            sys.exit(0)
        else:
            print "poll: Will shutdown on %s" % shutdown_on
        time.sleep(30)

class PingRequestHandler(SimpleHTTPServer.SimpleHTTPRequestHandler):
    def do_POST(self):
        shutdown_on = datetime.now() + shutdown_delta
        print "web: Will now shut down on %s" % shutdown_on

        self.send_response(200)
        self.send_header("Content-type", "text/plain")
        self.end_headers()
        self.wfile.writelines("ok - will shut down on %s" % shutdown_on)

    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-type", "text/plain")
        self.end_headers()
        self.wfile.writelines("will shut down on %s" % shutdown_on)


# Background thread: check to see if we need to halt the system.
timer = Process(target=poll_timer)
timer.start()

# Main thread: run a web server to reset the timer
server = SocketServer.TCPServer(('0.0.0.0', 8080), PingRequestHandler)
server.serve_forever()
