import importlib.machinery,importlib.util
from pathlib import Path
loader=importlib.machinery.SourceFileLoader('perchrequest',str(Path(__file__).resolve().parents[1]/'perch-request-hook'))
spec=importlib.util.spec_from_loader(loader.name,loader);bridge=importlib.util.module_from_spec(spec);loader.exec_module(bridge)
def handle(op,p):
    if op=='request-get':return {'request':bridge.read_request(p.get('id'))}
    if op=='request-reply':return bridge.respond(p)
    raise ValueError('Unknown request operation')
