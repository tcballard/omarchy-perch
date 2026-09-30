// Perch status extension v1 — owned by perch-extension-setup.
// Separate, opt-in permission bridge for the OpenCode v1 plugin API.
import { spawn } from 'node:child_process';
const adapter = __PERCH_REQUEST_ADAPTER__;
export const PerchRequests = async ({client, directory}) => {
    const pending = new Map();
    const identity = value => typeof value === 'string' && value.length > 0 && value.length <= 4096;
    function cancel(id) {
        const entry = pending.get(id);
        if (!entry) return;
        pending.delete(id);
        clearTimeout(entry.timer);
        entry.child.kill();
    }
    return {
        dispose: async () => { for (const id of pending.keys()) cancel(id); },
        event: async ({event}) => {
            const p = event?.properties;
            if (!p || !identity(p.sessionID)) return;
            if (event.type === 'permission.replied') {
                const entry = pending.get(p.requestID);
                if (entry?.sessionID === p.sessionID && !entry.applying) cancel(p.requestID);
                return;
            }
            if (event.type !== 'permission.asked' || !identity(p.id) || pending.has(p.id) || pending.size >= 8 ||
                typeof client?.postSessionIdPermissionsPermissionId !== 'function') return;
            if (typeof p.permission !== 'string' || !p.permission || p.permission.length > 160 ||
                !Array.isArray(p.patterns) || p.patterns.some(x => typeof x !== 'string') ||
                !p.metadata || typeof p.metadata !== 'object' || Array.isArray(p.metadata)) return;
            const input = {patterns:p.patterns, metadata:p.metadata};
            if (Buffer.byteLength(JSON.stringify(input)) > 16384) return;
            const raw = JSON.stringify({hook_event_name:'PermissionRequest', tool_name:p.permission,
                tool_input:input, cwd:directory});
            if (Buffer.byteLength(raw) > 65536) return;
            let child;
            try { child = spawn(adapter, ['--agent', 'opencode'], {stdio:['pipe','pipe','ignore'], windowsHide:true}); }
            catch (_) { return; }
            const entry = {child, sessionID:p.sessionID, applying:false, output:'', timer:null};
            pending.set(p.id, entry);
            entry.timer = setTimeout(() => cancel(p.id), 128000);
            child.stdin.on('error', () => {});
            child.on('error', () => cancel(p.id));
            child.on('exit', () => {
                if (pending.get(p.id) === entry) pending.delete(p.id);
                clearTimeout(entry.timer);
            });
            child.stdout.on('data', async chunk => {
                if (pending.get(p.id) !== entry || entry.applying) return;
                entry.output += chunk.toString();
                if (entry.output.length > 1024) { cancel(p.id); return; }
                if (!entry.output.includes('\n')) return;
                entry.applying = true;
                let delivered = false;
                try {
                    const response = JSON.parse(entry.output.split('\n')[0]).response;
                    if (response !== 'once' && response !== 'reject') throw Error('Invalid decision');
                    const result = await client.postSessionIdPermissionsPermissionId({
                        path:{id:p.sessionID, permissionID:p.id}, query:{directory}, body:{response},
                        signal:AbortSignal.timeout(5000)
                    });
                    delivered = !result.error && result.data === true;
                } catch (_) { /* No retry: an ambiguous response must not approve twice. */ }
                if (pending.get(p.id) === entry) child.stdin.end(JSON.stringify({delivered})+'\n');
            });
            child.stdin.write(raw+'\n');
        }
    };
};
