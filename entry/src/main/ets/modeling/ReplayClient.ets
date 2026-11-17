import { http } from '@kit.NetworkKit';
import { DecisionCandidate } from './DecisionEngine';

interface ReplayTaskContext {
  task_status: string;
  user_requested_help: boolean;
}

interface ReplayRequest {
  schema_version: string;
  source: string;
  timestamp_ms: number;
  context_quality: string;
  features: Record<string, number>;
  task_context: ReplayTaskContext;
}

interface ReplayFixture {
  name: string;
  target: string;
  request: ReplayRequest;
}

interface ReplayEnvelope {
  fixture: ReplayFixture;
}

/** Requests only the service's synthetic fixture. No AppState or sensor data is read. */
export class ReplayClient {
  private validBaseUrl(baseUrl: string): boolean {
    return baseUrl.startsWith('https://') || baseUrl.startsWith('http://127.0.0.1:');
  }

  private async requestText(url: string, method: http.RequestMethod,
                            body: string = ''): Promise<string | null> {
    const request = http.createHttp();
    try {
      const options: http.HttpRequestOptions = {
        method: method,
        connectTimeout: 1500,
        readTimeout: 1500,
        expectDataType: http.HttpDataType.STRING,
        header: { 'Content-Type': 'application/json' },
        extraData: body
      };
      const response: http.HttpResponse = await request.request(url, options);
      if (response.responseCode !== 200 || typeof response.result !== 'string') {
        return null;
      }
      return response.result as string;
    } catch (_error) {
      return null;
    } finally {
      request.destroy();
    }
  }

  async nextSyntheticCandidate(baseUrl: string): Promise<DecisionCandidate | null> {
    if (!this.validBaseUrl(baseUrl)) {
      return null;
    }
    const root = baseUrl.replace(/\/$/, '');
    const replayText = await this.requestText(`${root}/v1/replay/next?cursor=2`, http.RequestMethod.GET);
    if (!replayText) {
      return null;
    }
    try {
      const envelope = JSON.parse(replayText) as ReplayEnvelope;
      if (envelope.fixture.target !== '/v1/m2/decision-candidate' ||
          envelope.fixture.request.source !== 'replay') {
        return null;
      }
      // The fixture stores aggregate features only. Stamp this replay request so
      // G0 can evaluate candidate age against the device clock.
      envelope.fixture.request.timestamp_ms = Date.now();
      const candidateText = await this.requestText(`${root}/v1/m2/decision-candidate`,
        http.RequestMethod.POST, JSON.stringify(envelope.fixture.request));
      if (!candidateText) {
        return null;
      }
      const candidate = JSON.parse(candidateText) as DecisionCandidate;
      if (candidate.schema_version !== '0.1-replay' || candidate.source !== 'replay' ||
          candidate.executable !== false) {
        return null;
      }
      return candidate;
    } catch (_error) {
      return null;
    }
  }
}
