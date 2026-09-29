import os
import selectors
import signal
import subprocess
import time

active = None

def cleanup(signum, frame):
    if active:
        try: os.killpg(active.pid,signal.SIGKILL)
        except ProcessLookupError: pass
        active.wait()
    raise SystemExit(1)

def run(argv, timeout=5, limit=65536):
    global active
    signal.signal(signal.SIGTERM,cleanup)
    active=subprocess.Popen(argv,stdin=subprocess.DEVNULL,stdout=subprocess.PIPE,stderr=subprocess.PIPE,start_new_session=True)
    process=active
    outputs={process.stdout:bytearray(),process.stderr:bytearray()}
    poll=selectors.DefaultSelector()
    for pipe in outputs:poll.register(pipe,selectors.EVENT_READ)
    deadline=time.monotonic()+timeout
    try:
        while poll.get_map():
            if time.monotonic()>=deadline:raise ValueError('Command timed out')
            for event,_ in poll.select(min(0.1,max(0,deadline-time.monotonic()))):
                data=os.read(event.fileobj.fileno(),8192)
                if not data:poll.unregister(event.fileobj);continue
                outputs[event.fileobj].extend(data)
                if len(outputs[event.fileobj])>limit:raise ValueError('Command output exceeds limit')
        process.wait(timeout=max(0.01,deadline-time.monotonic()))
        if process.returncode:raise ValueError('Command failed; check the integration or installed dependency')
        return bytes(outputs[process.stdout]).decode('utf-8',errors='replace')
    finally:
        try:os.killpg(process.pid,signal.SIGKILL)
        except ProcessLookupError:pass
        process.wait()
        poll.close()
        for pipe in outputs:pipe.close()
        active=None

def launch(argv):
    # Explicit open/share actions launch applications that must outlive the panel.
    child=subprocess.Popen(argv,stdin=subprocess.DEVNULL,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,start_new_session=True)
    time.sleep(0.05)
    if child.poll() not in (None,0):raise ValueError('Application could not be opened')
