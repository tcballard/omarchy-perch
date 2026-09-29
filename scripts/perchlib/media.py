import hashlib
import http.client
import ipaddress
import os
from pathlib import Path
import re
import signal
import socket
import ssl
import struct
import tempfile
import time
from urllib.parse import urlsplit,urljoin
from .storage import read_file
from .shelf import local

class PinnedHTTPS(http.client.HTTPSConnection):
    def connect(self):
        addresses=socket.getaddrinfo(self.host,self.port,type=socket.SOCK_STREAM)
        if not addresses or any(not ipaddress.ip_address(a[4][0]).is_global for a in addresses):raise ValueError('Artwork host is not a public address')
        sock=socket.socket(addresses[0][0],socket.SOCK_STREAM);sock.settimeout(3)
        try:
            sock.connect(addresses[0][4]);self.sock=self._context.wrap_socket(sock,server_hostname=self.host)
        except Exception:sock.close();raise

def dimensions(data):
    if data.startswith(b'\x89PNG\r\n\x1a\n') and len(data)>=24:return struct.unpack('>II',data[16:24])
    if data.startswith(b'\xff\xd8'):
        i=2
        while i+9<len(data):
            if data[i]!=255:raise ValueError('Invalid JPEG')
            marker=data[i+1];i+=2
            if marker in (0xd8,0xd9):continue
            length=int.from_bytes(data[i:i+2],'big')
            if length<2:raise ValueError('Invalid JPEG')
            if marker in (0xc0,0xc1,0xc2):return (int.from_bytes(data[i+5:i+7],'big'),int.from_bytes(data[i+3:i+5],'big'))
            i+=length
    raise ValueError('Artwork must be PNG or JPEG')

def artwork(url):
    if not isinstance(url,str) or len(url)>4096:raise ValueError('Invalid artwork URL')
    root=Path(os.environ.get('XDG_CACHE_HOME',str(Path.home()/'.cache')))/'omarchy-perch'
    root.mkdir(parents=True,exist_ok=True,mode=0o700)
    if root.is_symlink():raise ValueError('Unsafe artwork cache')
    target=root/(hashlib.sha256(url.encode()).hexdigest()+'.image')
    if target.exists() and time.time()-target.stat().st_mtime<86400:return {'art':target.as_uri()}
    def deadline(sig,frame):raise ValueError('Artwork request timed out')
    old=signal.signal(signal.SIGALRM,deadline);signal.alarm(7)
    try:
        for redirects in range(4):
            parts=urlsplit(url)
            if parts.scheme!='https' or not parts.hostname or parts.username or parts.password or parts.port not in (None,443):raise ValueError('Only public HTTPS artwork is supported')
            connection=PinnedHTTPS(parts.hostname,443,timeout=3,context=ssl.create_default_context())
            try:
                connection.request('GET',(parts.path or '/')+('?' +parts.query if parts.query else ''),headers={'User-Agent':'Perch/0.1','Accept':'image/png,image/jpeg'})
                response=connection.getresponse()
                if response.status in (301,302,303,307,308):url=urljoin(url,response.getheader('Location',''));continue
                if response.status!=200:raise ValueError('Artwork provider returned an error')
                if int(response.getheader('Content-Length','0'))>2097152:raise ValueError('Artwork exceeds 2 MiB')
                data=response.read(2097153)
                if len(data)>2097152:raise ValueError('Artwork exceeds 2 MiB')
                width,height=dimensions(data)
                if width<1 or height<1 or width>4096 or height>4096 or width*height>8388608:raise ValueError('Artwork dimensions exceed limits')
                fd,tmp=tempfile.mkstemp(prefix='.cover-',dir=root)
                try:
                    with os.fdopen(fd,'wb') as out:out.write(data)
                    os.replace(tmp,target)
                finally:
                    if os.path.exists(tmp):os.unlink(tmp)
                cached=sorted(root.glob('*.image'),key=lambda p:p.stat().st_mtime,reverse=True)
                for stale in cached[32:]:stale.unlink()
                return {'art':target.as_uri()}
            finally:connection.close()
        raise ValueError('Too many artwork redirects')
    finally:signal.alarm(0);signal.signal(signal.SIGALRM,old)

def lyrics(path):
    path=local(path)
    if path.suffix.lower() not in ('.lrc','.txt'):raise ValueError('Choose local .lrc or .txt lyrics')
    raw=read_file(path,65536).decode('utf-8-sig',errors='replace');lines=[]
    for line in raw.splitlines()[:1000]:
        matches=re.findall(r'\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]',line)
        words=re.sub(r'\[[^\]]*\]','',line)[:240]
        for minute,second,fraction in matches:
            lines.append({'time':int(minute)*60+int(second)+(int(fraction)/10**len(fraction) if fraction else 0),'text':words})
        if not matches and words.strip():lines.append({'time':-1,'text':words})
    return {'lyrics':sorted(lines,key=lambda l:l['time'])[:500]}
