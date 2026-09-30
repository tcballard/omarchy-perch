// Perch status extension v1 — owned by perch-extension-setup.
import { execFile } from 'node:child_process';
const adapter = __PERCH_ADAPTER__;
const agent = __PERCH_AGENT__;
export default function perchStatus(pi) {
    for (const [event, state] of [['agent_start','running'], ['agent_end','done'], ['session_shutdown','done']]) {
        pi.on(event, async (_event, ctx) => {
            try {
                const id = ctx.sessionManager.getSessionId();
                if (typeof id !== 'string' || !id || id.length > 4096) return;
                const data = JSON.stringify({session_id:id, state, cwd:ctx.cwd});
                await new Promise(resolve => {
                    const child = execFile(adapter, ['--perch-hook-v1', agent],
                        {timeout:2500, maxBuffer:1024, windowsHide:true}, () => resolve());
                    child.stdin.on('error', () => {});
                    child.stdin.end(data);
                });
            } catch (_) { /* Observers never interrupt the agent. */ }
        });
    }
}
