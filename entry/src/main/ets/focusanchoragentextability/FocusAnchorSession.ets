import { StudyTask } from '../models/AppTypes';

export interface ThoughtRecord {
  id: string;
  text: string;
  createdAt: number;
  linkedTaskTitle: string;
}

export interface FocusRuntime {
  consentFocusSupport: boolean;
  consentThoughtSandbox: boolean;
  activeTask?: StudyTask;
}

export interface AgentDecision {
  intent: string;
  userVisibleText: string;
  thoughtStored: boolean;
  companionPaused: boolean;
}

export class FocusAnchorSession {
  private static instance: FocusAnchorSession | undefined;
  companionPaused: boolean = false;
  thoughts: ThoughtRecord[] = [];
  lastText: string = '';

  static getInstance(): FocusAnchorSession {
    if (!FocusAnchorSession.instance) {
      FocusAnchorSession.instance = new FocusAnchorSession();
    }
    return FocusAnchorSession.instance;
  }

  addThought(text: string, linkedTaskTitle: string): void {
    const record: ThoughtRecord = {
      id: `thought_${Date.now()}`,
      text: text.slice(0, 500),
      createdAt: Date.now(),
      linkedTaskTitle: linkedTaskTitle
    };
    const updatedThoughts: ThoughtRecord[] = [record, ...this.thoughts];
    this.thoughts = updatedThoughts.slice(0, 20);
  }
}
