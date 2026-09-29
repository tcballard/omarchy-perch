import json
import re
import shutil

from .process import run

ADDRESS = re.compile(r'^0x[0-9a-fA-F]{1,16}$')


def handle(op, payload):
    if op != 'agent-jump':
        raise ValueError('Unsupported session operation')
    address = payload.get('address', '')
    if not isinstance(address, str) or not ADDRESS.fullmatch(address):
        raise ValueError('That session has no valid Hyprland window target')
    if not shutil.which('hyprctl'):
        raise ValueError('hyprctl is unavailable; the session was not focused')
    clients = json.loads(run(['hyprctl', '-j', 'clients'], timeout=.75, limit=262144))
    if not isinstance(clients, list) or not any(
        isinstance(client, dict) and client.get('address') == address for client in clients
    ):
        raise ValueError('That session window is no longer open')
    reply = run(['hyprctl', 'dispatch', 'focuswindow', 'address:' + address], timeout=1, limit=4096)
    if reply.strip() != 'ok':
        raise ValueError('Hyprland could not focus that session window')
    return {'message': 'Returned to session'}
