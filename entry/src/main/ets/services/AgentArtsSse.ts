/** Offline, transport-independent parser for a completed AgentArts workflow SSE response. */
export interface AgentArtsFinalOutput {
  executionId: string;
  outputs: Record<string, unknown>;
}

export class AgentArtsSseError extends Error {
  code: string;
  constructor(code: string) { super(code); this.code = code; }
}

function record(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

export function parseAgentArtsWorkflowSse(stream: string): AgentArtsFinalOutput {
  if (typeof stream !== 'string' || stream.length === 0 || stream.length > 1024 * 1024) {
    throw new AgentArtsSseError('AGENTARTS_INVALID_STREAM');
  }
  let terminal: Record<string, unknown> | undefined;
  let ended = false;
  const blocks = stream.replace(/\r\n/g, '\n').split(/\n\n/);
  for (const block of blocks) {
    if (!block.trim()) continue;
    const dataLines = block.split('\n').filter(line => line.startsWith('data:'));
    if (dataLines.length === 0) throw new AgentArtsSseError('AGENTARTS_INVALID_STREAM');
    let item: unknown;
    try { item = JSON.parse(dataLines.map(line => line.slice(5).trimStart()).join('\n')); }
    catch { throw new AgentArtsSseError('AGENTARTS_INVALID_STREAM'); }
    if (!record(item) || typeof item.event !== 'string') throw new AgentArtsSseError('AGENTARTS_INVALID_STREAM');
    if (ended) throw new AgentArtsSseError('AGENTARTS_INVALID_STREAM');
    if (item.event === 'error' || item.event === 'exception') throw new AgentArtsSseError('AGENTARTS_REMOTE_ERROR');
    if (item.event === 'node_wait') throw new AgentArtsSseError('AGENTARTS_NOT_COMPLETED');
    if (item.event === 'workflow_finished') {
      if (terminal) throw new AgentArtsSseError('AGENTARTS_INVALID_STREAM');
      if (!record(item.data)) throw new AgentArtsSseError('AGENTARTS_INVALID_STREAM');
      terminal = item.data;
    }
    if (item.event === 'end') ended = true;
  }
  if (!ended || !terminal) throw new AgentArtsSseError('AGENTARTS_INVALID_STREAM');
  const status = terminal.status;
  if (!record(status) || status.code !== 1 || status.desc !== 'succeeded') {
    throw new AgentArtsSseError('AGENTARTS_NOT_COMPLETED');
  }
  if (typeof terminal.execution_id !== 'string' || !terminal.execution_id.trim() || !record(terminal.outputs)) {
    throw new AgentArtsSseError('AGENTARTS_INVALID_OUTPUT');
  }
  return { executionId: terminal.execution_id, outputs: terminal.outputs };
}
