import { Want } from '@kit.AbilityKit';
import { formBindingData, formInfo, FormExtensionAbility } from '@kit.FormKit';
import { FocusCardService } from '../services/FocusCardService';
import { TaskFileService } from '../services/TaskFileService';
import { ActionEvent } from '../models/AppTypes';
import { ActionEventService } from '../services/ActionEventService';
import { cardEventForTap } from '../services/CardEventProtocol';

export default class FocusTaskCardAbility extends FormExtensionAbility {
  onAddForm(want: Want): formBindingData.FormBindingData {
    const formId = `${want.parameters?.[formInfo.FormParam.IDENTITY_KEY] ?? ''}`;
    this.loadAndRefresh(formId);
    return FocusCardService.binding([]);
  }

  onUpdateForm(formId: string): void {
    this.loadAndRefresh(formId);
  }

  onFormEvent(formId: string, message: string): void {
    try {
      const envelope = JSON.parse(message) as Record<string, string>;
      const event = envelope['message'] ?
        JSON.parse(envelope['message']) as Record<string, string> : envelope;
      const taskId = `${event['taskId'] ?? ''}`;
      const actionId = `${event['actionId'] ?? ''}`;
      const revision = Number(event['revision'] ?? 0);
      const action = `${event['action'] ?? ''}`;
      this.handleTap(taskId, actionId, revision, action).catch(() => {
        console.error('Focus card action failed');
      });
    } catch (error) {
      console.error('Invalid focus card event');
    }
  }

  private async handleTap(taskId: string, actionId: string, revision: number, action: string): Promise<void> {
    const tapped = cardEventForTap(taskId, actionId, revision, action, Date.now());
    if (tapped) {
      const event: ActionEvent = {
        eventId: tapped.eventId,
        taskId: tapped.taskId,
        actionId: tapped.actionId,
        baseRevision: tapped.baseRevision,
        type: tapped.type,
        origin: 'card',
        createdAt: tapped.createdAt
      };
      const result = await ActionEventService.apply(this.context, event);
      if (result.status === 'applied') {
        return;
      }
    }
    // Legacy, stale, or duplicate card bindings are replaced with the phone's projection.
    const file = TaskFileService.getInstance();
    file.init(this.context);
    await FocusCardService.refresh(this.context, await file.loadTasks());
  }

  onRemoveForm(formId: string): void {
    FocusCardService.remove(this.context, formId).catch(() => {});
  }

  onDeleteForm(formId: string): void {
    this.onRemoveForm(formId);
  }

  private async loadAndRefresh(formId: string): Promise<void> {
    try {
      await FocusCardService.add(this.context, formId);
      const file = TaskFileService.getInstance();
      file.init(this.context);
      await FocusCardService.refresh(this.context, await file.loadTasks());
    } catch (error) {
      console.error('Focus card load failed');
    }
  }
}
