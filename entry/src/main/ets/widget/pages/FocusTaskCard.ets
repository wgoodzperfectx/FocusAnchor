let cardStorage: LocalStorage = new LocalStorage();

@Entry(cardStorage)
@Component
struct FocusTaskCard {
  @LocalStorageProp('taskTitle') taskTitle: string = '今天准备开始什么？';
  @LocalStorageProp('stepText') stepText: string = '打开应用，选择一个小行动';
  @LocalStorageProp('stepStatus') stepStatus: string = 'empty';
  @LocalStorageProp('taskId') taskId: string = '';
  @LocalStorageProp('actionId') actionId: string = '';
  @LocalStorageProp('revision') revision: number = 0;

  build() {
    Column({ space: 12 }) {
      Text('FocusAnchor · 当前一步')
        .fontSize(14)
        .fontColor('#A4B0AD')
        .width('100%');
      Text(this.taskTitle)
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor('#F5F7F4')
        .maxLines(2)
        .width('100%');
      Text(this.stepText)
        .fontSize(17)
        .fontColor('#D6DEDA')
        .maxLines(2)
        .width('100%');
      if (this.actionId && this.revision > 0 && (this.stepStatus === 'ready' || this.stepStatus === 'paused')) {
        Button('开始这一步')
          .onClick(() => this.send('start'));
      } else if (this.actionId && this.revision > 0 && this.stepStatus === 'in_progress') {
        Button('完成这一步')
          .onClick(() => this.send('complete'));
      } else {
        Button(this.stepStatus === 'completed' ? '已完成 · 查看下一步' : '打开应用')
          .onClick(() => this.openApp());
      }
    }
    .width('100%')
    .height('100%')
    .padding(16)
    .backgroundColor('#101517');
  }

  private send(action: string): void {
    postCardAction(this, {
      action: 'message',
      params: { message: JSON.stringify({ action, taskId: this.taskId,
        actionId: this.actionId, revision: this.revision }) }
    });
  }

  private openApp(): void {
    postCardAction(this, { action: 'router', abilityName: 'EntryAbility' });
  }
}
