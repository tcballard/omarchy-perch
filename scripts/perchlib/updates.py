"""Updates remain owned by Omarchy's installed-plugin lifecycle."""
from pathlib import Path
import shutil
from .process import run

ROOT=Path(__file__).resolve().parents[2]
ID='io.github.tcballard.perch'


def installation():
    return Path.home()/'.config/omarchy/plugins'/ID


def availability():
    path=installation()
    if path.is_symlink() or not (path/'.git').is_dir() or path.resolve()!=ROOT:
        return 'manual install'
    return 'available' if shutil.which('omarchy-plugin-update') else 'host updater missing'


def apply():
    if availability()!='available':raise ValueError('Update this development/manual install through its original install method')
    path=str(installation())
    def git(*args):return run(['git','-C',path,*args],timeout=3,limit=16384).strip()
    if git('status','--porcelain'):raise ValueError('Perch has local changes; update them manually')
    current=git('symbolic-ref','--quiet','--short','HEAD')
    default=git('symbolic-ref','--quiet','refs/remotes/origin/HEAD')
    if not default.startswith('refs/remotes/origin/') or current!=default.removeprefix('refs/remotes/origin/'):
        raise ValueError('Perch is on a review or custom branch; update it manually')
    # The host owns fast-forward, manifest validation, rollback and shell rescan.
    # No reset, checkout, remote rewrite or arbitrary plugin target is accepted here.
    run(['omarchy-plugin-update',ID,'--yes'],timeout=75,limit=16384,detail=True)
    return {'message':'Perch update checked by Omarchy. Review Setup for installed hook/companion updates.'}
