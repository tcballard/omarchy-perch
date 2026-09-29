import contextlib
import fcntl
import json
import os
from pathlib import Path
import stat
import tempfile

LIMIT = 262144

def read_file(path, limit=LIMIT, follow=False):
    """Read a regular file of at most `limit` bytes. Dotfile-managed configuration may be a symlink."""
    fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK | (0 if follow else os.O_NOFOLLOW))
    with os.fdopen(fd, 'rb') as source:
        info = os.fstat(source.fileno())
        if not stat.S_ISREG(info.st_mode) or info.st_size > limit:
            raise ValueError('File is not regular or exceeds the size limit')
        data = source.read(limit + 1)
        if len(data) > limit:
            raise ValueError('File grew beyond the size limit')
        return data

def read_head(path, limit):
    """The first `limit` bytes of a regular file of any size, for previews."""
    fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK | os.O_NOFOLLOW)
    with os.fdopen(fd, 'rb') as source:
        if not stat.S_ISREG(os.fstat(source.fileno()).st_mode):
            raise ValueError('Only regular files can be previewed')
        return source.read(limit)

class Store:
    def __init__(self, name):
        if name not in ('shelf','calendar','notifications','integrations'):
            raise ValueError('Unknown state store')
        self.root = Path(os.environ.get('XDG_STATE_HOME', str(Path.home()/'.local/state'))) / 'omarchy-perch'
        self.root.mkdir(parents=True, exist_ok=True, mode=0o700)
        if self.root.is_symlink() or self.root.stat().st_uid != os.getuid():
            raise ValueError('Unsafe state directory')
        os.chmod(self.root, 0o700)
        self.path = self.root / (name + '.json')
    @contextlib.contextmanager
    def lock(self):
        fd = os.open(self.root / '.lock', os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
        try:
            fcntl.flock(fd,fcntl.LOCK_EX)
            yield
        finally:
            os.close(fd)
    def load(self, default):
        try:
            return json.loads(read_file(self.path))
        except FileNotFoundError:
            return default
    def save(self, value):
        data=json.dumps(value,ensure_ascii=True).encode()
        if len(data)>LIMIT: raise ValueError('State exceeds size limit')
        fd,tmp=tempfile.mkstemp(prefix='.write-',dir=self.root)
        try:
            with os.fdopen(fd,'wb') as out:
                out.write(data);out.flush();os.fsync(out.fileno())
            os.replace(tmp,self.path)
        finally:
            if os.path.exists(tmp):os.unlink(tmp)
