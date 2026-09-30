"""Versioned, data-only native cards from explicitly selected installed plugins."""
import json
import re
from . import plugins
from .process import run

TOKEN = re.compile(r'[A-Za-z0-9][A-Za-z0-9._:-]{0,159}')

def token(value):
    return isinstance(value, str) and TOKEN.fullmatch(value) is not None

def text(value, limit):
    if not isinstance(value, str):
        raise ValueError('Invalid card text')
    return ''.join(c if ord(c) >= 32 else ' ' for c in value)[:limit]

def normalize(value):
    if not isinstance(value, dict) or type(value.get('version')) is not int or value['version'] != 1:
        raise ValueError('This plugin does not provide a supported Perch card yet')
    if not token(value.get('revision')) or value.get('status') not in ('ready', 'empty', 'loading', 'error', 'offline'):
        raise ValueError('Invalid card state')
    actions = value.get('actions', [])
    rows = value.get('rows', [])
    if not isinstance(actions, list) or len(actions) > 4 or not isinstance(rows, list) or len(rows) > 8:
        raise ValueError('Card exceeds its item limit')
    ids = set()
    def action(a):
        if not isinstance(a, dict) or not token(a.get('id')) or a['id'] in ids:
            raise ValueError('Invalid or duplicate card action')
        ids.add(a['id'])
        return {'id': a['id'], 'label': text(a.get('label'), 40)}
    result = {'version': 1, 'revision': value['revision'], 'status': value['status'],
              'title': text(value.get('title'), 100), 'summary': text(value.get('summary', ''), 240),
              'actions': [action(a) for a in actions], 'rows': []}
    row_ids = set()
    for row in rows:
        if not isinstance(row, dict) or not token(row.get('id')) or row['id'] in row_ids:
            raise ValueError('Invalid or duplicate card row')
        row_ids.add(row['id'])
        result['rows'].append({'id': row['id'], 'title': text(row.get('title'), 180),
                               'detail': text(row.get('detail', ''), 240),
                               'action': action(row['action']) if row.get('action') is not None else None})
    return result

def snapshot(id):
    raw = run(['omarchy-shell', id, 'perchCard'], timeout=2, limit=32768)
    try:
        return normalize(json.loads(raw))
    except json.JSONDecodeError as error:
        raise ValueError('This plugin does not provide a supported Perch card yet. Use Open for its full panel.') from error

def handle(op, payload):
    id = payload.get('id')
    if op not in ('card-read', 'card-action') or not plugins.valid_id(id):
        raise ValueError('Invalid card request')
    match = next((p for p in plugins.catalog() if p['id'] == id), None)
    if not match or not match['enabled']:
        raise ValueError('Plugin is missing or disabled. Manage it in Omarchy.')
    card = snapshot(id)
    if op == 'card-action':
        requested = payload.get('action')
        allowed = card['actions'] + [r['action'] for r in card['rows'] if r['action']]
        if payload.get('revision') != card['revision']:
            raise ValueError('This card changed. Refresh it before trying again.')
        if not token(requested) or not any(a['id'] == requested for a in allowed):
            raise ValueError('That action is no longer available')
        request = json.dumps({'version': 1, 'revision': card['revision'], 'action': requested})
        reply = json.loads(run(['omarchy-shell', id, 'perchAction', request], timeout=2, limit=4096))
        if not isinstance(reply, dict) or reply.get('ok') is not True:
            raise ValueError('Plugin could not complete that action. Refresh its card.')
        # The action succeeded even if reading its new state fails. Do not invite
        # a duplicate retry of an already completed action.
        try:
            card = snapshot(id)
        except (ValueError, OSError):
            return {'card': None, 'message': 'Action completed. Refresh to see the latest state.'}
    return {'card': card, 'message': 'Action completed' if op == 'card-action' else ''}
