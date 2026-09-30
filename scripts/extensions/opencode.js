// Perch status extension v1 — owned by perch-extension-setup.
import { execFile } from 'node:child_process';
const adapter = __PERCH_ADAPTER__;
export const PerchStatus = async ({directory}) => ({
    event: async ({event}) => {
        try {
            const p = event?.properties;
            if (!p || typeof p.sessionID !== 'string' || !p.sessionID || p.sessionID.length > 4096) return;
            let state, attention;
            if (event.type === 'session.status') {
                state = {busy:'running', retry:'running', idle:'done'}[p.status?.type];
            } else if (event.type === 'session.idle') state = 'done';
            else if (event.type === 'session.error') state = 'error';
            else if (event.type === 'permission.asked') { state = 'waiting'; attention = 'approval'; }
            else if (event.type === 'permission.replied') state = 'running';
            else if (event.type === 'question.asked') { state = 'waiting'; attention = 'question'; }
            else if (event.type === 'question.replied' || event.type === 'question.rejected') state = 'running';
            if (!state) return;
            const data = JSON.stringify({session_id:p.sessionID, state, attention, cwd:directory});
            await new Promise(resolve => {
                const child = execFile(adapter, ['--perch-hook-v1', 'opencode'],
                    {timeout:2500, maxBuffer:1024, windowsHide:true}, () => resolve());
                child.stdin.on('error', () => {});
                child.stdin.end(data);
            });
        } catch (_) { /* No permissions, prompts or tool content leave the client. */ }
    }
});
