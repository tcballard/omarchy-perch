import configparser
from itertools import islice
from pathlib import Path
import re
from urllib.parse import urlsplit
from .storage import read_file
from .process import launch

def catalog():
    apps={}
    for folder in [Path('/usr/share/applications'),Path.home()/'.local/share/applications']:
        for path in islice(folder.glob('*.desktop'),1200):
            if not re.fullmatch(r'[A-Za-z0-9._][A-Za-z0-9._-]*\.desktop',path.name):continue
            try:
                config=configparser.ConfigParser(interpolation=None,strict=False)
                config.read_string(read_file(path,65536,follow=True).decode());entry=config['Desktop Entry']
                if entry.get('Type')!='Application' or entry.get('Hidden')=='true' or entry.get('NoDisplay')=='true':continue
                apps[path.name]={'id':path.name,'name':entry.get('Name',path.stem)[:100]}
            except (OSError,ValueError,KeyError,configparser.Error):continue
    return sorted(apps.values(),key=lambda x:x['name'].casefold())[:500]

def handle(op,p):
    if op == 'app-link':
        url=p.get('url','')
        if not isinstance(url,str) or len(url)>2048 or any(ord(c)<33 for c in url):raise ValueError('Enter an HTTP or HTTPS URL')
        parsed=urlsplit(url)
        if parsed.scheme not in ('http','https') or not parsed.hostname or parsed.username or parsed.password:raise ValueError('Enter an HTTP or HTTPS URL without credentials')
        launch(['xdg-open',url])
        return {'message':'Link opened'}
    apps=catalog()
    if op=='app-open':
        if not any(a['id']==p.get('id') for a in apps):raise ValueError('Application is no longer installed')
        launch(['gtk-launch',p['id']])
        return {'message':'Application launch requested'}
    return {'apps':apps}
