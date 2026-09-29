import configparser
from itertools import islice
from pathlib import Path
import re
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
    apps=catalog()
    if op=='app-open':
        if not any(a['id']==p.get('id') for a in apps):raise ValueError('Application is no longer installed')
        launch(['gtk-launch',p['id']])
        return {'message':'Application launch requested'}
    return {'apps':apps}
