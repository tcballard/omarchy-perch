"""Explicit plugin launcher through Omarchy's public CLI; no QML loading."""
import json
import re
from .process import run

SELF = 'io.github.tcballard.perch'
VISUAL = {'panel', 'overlay', 'menu', 'bar-widget'}

def valid_id(value):
    return isinstance(value, str) and len(value) <= 160 and re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._-]*', value) is not None

def catalog():
    rows = json.loads(run(['omarchy-shell', 'shell', 'listPlugins'], timeout=3, limit=262144))
    if not isinstance(rows, list) or len(rows) > 2000:
        raise ValueError('Invalid plugin catalog')
    result = {}
    for row in rows:
        if not isinstance(row, dict):
            continue
        id = row.get('id')
        kinds = row.get('kinds')
        if not valid_id(id) or id == SELF or row.get('firstParty') is not False or id.startswith('omarchy.'):
            continue
        if not isinstance(kinds, list) or not any(k in VISUAL for k in kinds if isinstance(k, str)):
            continue
        name = row.get('name')
        result[id] = {'id': id, 'name': name[:100] if isinstance(name, str) else id,
                      'enabled': row.get('enabled') is True}
    if len(result) > 300:
        raise ValueError('Plugin catalog exceeds 300 launchable plugins')
    return sorted(result.values(), key=lambda row: (row['name'].casefold(), row['id']))

def handle(op, payload):
    if op == 'plugin-list':
        return {'plugins': catalog()}
    id = payload.get('id')
    if op != 'plugin-open' or not valid_id(id):
        raise ValueError('Invalid plugin request')
    # Recheck immediately before launch: never trust a persisted pin or stale UI.
    match = next((row for row in catalog() if row['id'] == id), None)
    if not match:
        raise ValueError('Plugin was removed or has no supported visual entry point')
    if not match['enabled']:
        raise ValueError('Plugin is disabled. Enable it in Omarchy first.')
    reply = run(['omarchy-shell', 'shell', 'summon', id, '{}'], timeout=3, limit=4096).strip()
    if reply != 'ok':
        raise ValueError('Omarchy could not open this plugin; its panel may be unavailable')
    return {'message': 'Opened ' + match['name']}
