import hashlib
import mimetypes
from pathlib import Path
import shutil
from urllib.parse import urlsplit,unquote
from .storage import Store,read_file
from .process import launch

def local(value):
    if not isinstance(value,str) or len(value)>4096 or '\x00' in value:raise ValueError('Invalid file path')
    parsed=urlsplit(value)
    if parsed.scheme:
        if parsed.scheme!='file' or parsed.netloc not in ('','localhost') or parsed.query or parsed.fragment:raise ValueError('Only local file URLs can be placed on the shelf')
        value=unquote(parsed.path)
    path=Path(value).expanduser()
    if not path.is_absolute():raise ValueError('Use an absolute path')
    path=path.resolve(strict=True)
    if not (path.is_file() or path.is_dir()):raise ValueError('Only regular files and folders are supported')
    return path

def describe(path):
    p=Path(path);exists=p.exists();mime=mimetypes.guess_type(p.name)[0] or 'application/octet-stream'
    return {'id':hashlib.sha256(str(p).encode()).hexdigest()[:24],'path':str(p),'url':p.as_uri(),'name':p.name[:160], 'exists':exists,'folder':p.is_dir(),'mime':mime,'size':p.stat().st_size if exists and p.is_file() else 0}

def handle(op,p):
    store=Store('shelf')
    with store.lock():
        paths=store.load([])
        if not isinstance(paths,list) or len(paths)>32 or any(not isinstance(x,str) or not Path(x).is_absolute() for x in paths):raise ValueError('Shelf state is invalid; preserve it before resetting')
        if op=='shelf-add':
            values=p.get('urls',[])
            if not isinstance(values,list) or len(values)>32:raise ValueError('Drop at most 32 files')
            new=[str(local(x)) for x in values]
            paths=list(dict.fromkeys(new+paths))
            if len(paths)>32:raise ValueError('Shelf is full (32 items). Remove an item first.')
            store.save(paths)
        elif op=='shelf-remove':
            paths=[x for x in paths if describe(x)['id']!=p.get('id')];store.save(paths)
        elif op in ('shelf-open','shelf-reveal','shelf-share','shelf-preview'):
            chosen=next((x for x in paths if describe(x)['id']==p.get('id')),None)
            if chosen is None:raise ValueError('Shelf item no longer exists')
            path=local(chosen)
            if op=='shelf-preview':
                mime=mimetypes.guess_type(path.name)[0] or ''
                if path.is_file() and (mime.startswith('text/') or path.suffix.lower() in ('.md','.log','.json','.qml','.py','.rs','.js','.toml','.yaml','.yml','.ics')):
                    text=read_file(path,65536).decode('utf-8',errors='replace')[:8000]
                    return {'preview':text,'kind':'text','name':path.name}
                return {'preview':path.as_uri() if mime in ('image/png','image/jpeg','image/webp') and path.stat().st_size<=2097152 else '', 'kind':'image' if mime in ('image/png','image/jpeg','image/webp') and path.stat().st_size<=2097152 else 'external','name':path.name}
            if op=='shelf-share':
                executable=shutil.which('localsend') or shutil.which('localsend_app')
                if not executable:raise ValueError('Install LocalSend to share files; no transfer was started')
                launch([executable,str(path)])
            else:launch(['xdg-open',(path.parent if op=='shelf-reveal' else path).as_uri()])
        return {'items':[describe(x) for x in paths]}
