export interface WearFlashNote {
  flashId: string;
  content: string;
  sourceDevice: 'watch';
  createdAt: number;
  syncStatus: 'pending';
}

export function flashIdForSequence(deviceId: string, sequence: number): string {
  return `watch_${encodeURIComponent(deviceId)}_${sequence}`;
}

/** The watch persists pending() before sending it over distributed KV. */
export class WearFlashQueue {
  private notes: WearFlashNote[];

  constructor(initial: WearFlashNote[] = []) {
    this.notes = [];
    for (const note of initial) {
      this.enqueue(note);
    }
  }

  enqueue(note: WearFlashNote): void {
    if (note && typeof note.flashId === 'string' && note.flashId &&
      typeof note.content === 'string' && note.content.trim() &&
      note.sourceDevice === 'watch' &&
      !this.notes.some((item: WearFlashNote) => item.flashId === note.flashId)) {
      this.notes.push(note);
    }
  }

  pending(): WearFlashNote[] {
    return [...this.notes];
  }

  ack(flashId: string): void {
    this.notes = this.notes.filter((note: WearFlashNote) => note.flashId !== flashId);
  }
}
