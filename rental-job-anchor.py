#!/usr/bin/env python3
import os
import signal

stopping = False

def reap(_signum=None, _frame=None):
    while True:
        try:
            pid, _status = os.waitpid(-1, os.WNOHANG)
        except ChildProcessError:
            return
        if pid == 0:
            return

def stop(_signum, _frame):
    global stopping
    stopping = True

signal.signal(signal.SIGCHLD, reap)
signal.signal(signal.SIGTERM, stop)
signal.signal(signal.SIGINT, stop)
while not stopping:
    signal.pause()
reap()
