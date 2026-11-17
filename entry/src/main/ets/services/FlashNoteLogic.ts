export interface FlashNoteRecord {
  flashId: string;
  content: string;
  sourceDevice: 'watch' | 'phone';
  createdAt: number;
  syncStatus: 'pending' | 'synced';
  convertedTaskId?: string;
  archived?: boolean;
}

export function flashTaskId(flashId: string): string {
  return `from_flash_${encodeURIComponent(flashId)}`;
}

export function mergeFlashNotes(notes: FlashNoteRecord[], arrivals: FlashNoteRecord[]): FlashNoteRecord[] {
  const result = notes.slice();
  for (const arrival of arrivals) {
    if (!arrival.flashId || !arrival.content.trim()) {
      continue;
    }
    if (!result.some((note: FlashNoteRecord) => note.flashId === arrival.flashId)) {
      result.push({ ...arrival, syncStatus: 'synced' });
    }
  }
  return result;
}

export function markFlashConverted(notes: FlashNoteRecord[], flashId: string, taskId: string): FlashNoteRecord[] {
  return notes.map((note: FlashNoteRecord): FlashNoteRecord => note.flashId === flashId ?
    { ...note, convertedTaskId: taskId } : note);
}

export function archiveFlash(notes: FlashNoteRecord[], flashId: string): FlashNoteRecord[] {
  return notes.map((note: FlashNoteRecord): FlashNoteRecord => note.flashId === flashId ?
    { ...note, archived: true } : note);
}
