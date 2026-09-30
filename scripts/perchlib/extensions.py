"""Owned local extension files. No package manager, network or client config edits."""
import json
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
AGENTS = ('pi', 'omp', 'opencode')
MARKER = '// Perch status extension v1 — owned by perch-extension-setup.\n'


def target(agent):
    if agent == 'opencode':
        return Path(os.environ.get('XDG_CONFIG_HOME', str(Path.home()/'.config')))/'opencode/plugins/perch-status.js'
    if agent not in AGENTS:
        raise ValueError('Unknown extension client')
    # Explicit environment overrides only; never guess a named profile.
    base = Path(os.environ.get('PI_CODING_AGENT_DIR', str(Path.home()/('.pi' if agent == 'pi' else '.omp')/'agent')))
    return base/'extensions/perch-status.js'


def render(agent):
    if agent not in AGENTS:
        raise ValueError('Unknown extension client')
    source = (ROOT/'scripts/extensions'/('opencode.js' if agent == 'opencode' else 'pi.js')).read_text()
    return source.replace('__PERCH_ADAPTER__', json.dumps(str(Path.home()/'.local/share/omarchy-perch/perch-agent-hook'))).replace('__PERCH_AGENT__', json.dumps(agent))


def health(agent):
    path = target(agent)
    if path.is_symlink():return 'occupied'
    if not path.exists():return 'not configured'
    if path.stat().st_size > 65536:return 'occupied'
    text = path.read_text()
    return 'enabled' if text == render(agent) else 'outdated' if text.startswith(MARKER) else 'occupied'
