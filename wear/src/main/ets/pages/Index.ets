import { common } from '@kit.AbilityKit';
import { distributedKVStore } from '@kit.ArkData';
import { preferences } from '@kit.ArkData';

interface WearTask {
  id: string;
  title: string;
  content: string;
  studyMinutes: number;
  studyMethod: string;
  priority: number;
  basePriority: number;
  completed: boolean;
  createdAt: number;
  dueAt?: number;
  insight?: string;
}

interface TaskSyncBundle {
  updatedAt: number;
  tasks: WearTask[];
}

/** Round-watch safe insets (avoid clipping at bezel). */
const SAFE_H: number = 22;
const SAFE_V_TOP: number = 28;
const SAFE_V_BOT: number = 34;

@Entry
@Component
struct Index {
  @State allTasks: WearTask[] = [];
  @State tasks: WearTask[] = [];
  @State statusText: string = '';
  @State currentIndex: number = 0;
  @State lang: number = 0;
  @State clockText: string = '00:00';
  @State bpm: number = 78;
  @State editing: boolean = false;
  @State editId: string = '';
  @State editTitle: string = '';
  @State editPriority: number = 2;
  @State editDueOffsetDays: number = 1;
  @State isNew: boolean = false;
  @State pageSize: number = 200;
  private kvStore: distributedKVStore.SingleKVStore | undefined = undefined;
  private clockId: number = -1;
  private pref: preferences.Preferences | undefined = undefined;
  private localStamp: number = 0;
  private writing: boolean = false;
  private swiperController: SwiperController = new SwiperController();

  aboutToAppear(): void {
    this.initLocal();
    this.initSync();
    this.tickClock();
    this.clockId = setInterval(() => this.tickClock(), 1000);
  }

  aboutToDisappear(): void {
    if (this.clockId !== -1) {
      clearInterval(this.clockId);
      this.clockId = -1;
    }
  }

  onPageShow(): void {
    this.loadLang();
  }

  private tickClock(): void {
    const now = new Date();
    const hh = now.getHours().toString().padStart(2, '0');
    const mm = now.getMinutes().toString().padStart(2, '0');
    this.clockText = `${hh}:${mm}`;
  }

  /** Content width inside circular safe zone (~70% of diameter). */
  private contentW(): number {
    return Math.max(120, this.pageSize * 0.72);
  }

  private tx(key: string): string {
    if (this.lang === 1) {
      if (key === 'home') {
        return '首页';
      }
      if (key === 'tasks') {
        return '任务';
      }
      if (key === 'focus') {
        return '焦点';
      }
      if (key === 'sync_ok') {
        return '已同步';
      }
      if (key === 'sync_empty') {
        return '暂无任务';
      }
      if (key === 'sync_fail') {
        return '同步不可用';
      }
      if (key === 'title') {
        return '焦点锚';
      }
      if (key === 'add') {
        return '新建';
      }
      if (key === 'edit') {
        return '编辑';
      }
      if (key === 'save') {
        return '存';
      }
      if (key === 'cancel') {
        return '取消';
      }
      if (key === 'done') {
        return '完成';
      }
      if (key === 'delete') {
        return '删';
      }
      if (key === 'title_hint') {
        return '标题';
      }
      if (key === 'saved') {
        return '已保存';
      }
      return key;
    }
    if (key === 'home') {
      return 'Home';
    }
    if (key === 'tasks') {
      return 'Tasks';
    }
    if (key === 'focus') {
      return 'Focus';
    }
    if (key === 'sync_ok') {
      return 'OK';
    }
    if (key === 'sync_empty') {
      return 'Empty';
    }
    if (key === 'sync_fail') {
      return 'Offline';
    }
    if (key === 'title') {
      return 'Focus';
    }
    if (key === 'add') {
      return 'New';
    }
    if (key === 'edit') {
      return 'Edit';
    }
    if (key === 'save') {
      return 'OK';
    }
    if (key === 'cancel') {
      return 'Back';
    }
    if (key === 'done') {
      return 'Done';
    }
    if (key === 'delete') {
      return 'Del';
    }
    if (key === 'title_hint') {
      return 'Title';
    }
    if (key === 'saved') {
      return 'Saved';
    }
    return key;
  }

  private async initLocal(): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      this.pref = await preferences.getPreferences(context, 'wear_focux');
      await this.loadLang();
      await this.loadLocalTasks();
    } catch (_e) {
      this.lang = 0;
    }
  }

  private async loadLang(): Promise<void> {
    if (!this.pref) {
      return;
    }
    const v = await this.pref.get('language', 0);
    this.lang = typeof v === 'number' ? (v === 1 ? 1 : 0) : 0;
  }

  private async loadLocalTasks(): Promise<void> {
    if (!this.pref) {
      return;
    }
    try {
      const stamp = await this.pref.get('tasks_stamp', 0);
      this.localStamp = typeof stamp === 'number' ? stamp : 0;
      const raw = await this.pref.get('tasks_json', '');
      if (typeof raw === 'string' && raw.length > 0) {
        const parsed = JSON.parse(raw) as WearTask[];
        if (Array.isArray(parsed)) {
          this.applyTaskList(parsed);
        }
      }
    } catch (_e) {
      // ignore
    }
  }

  private applyTaskList(list: WearTask[]): void {
    this.allTasks = list;
    this.tasks = list.filter((t: WearTask) => !t.completed);
  }

  private async initSync(): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const kvManager = distributedKVStore.createKVManager({
        context: context,
        bundleName: context.abilityInfo.bundleName
      });
      const config: distributedKVStore.Options = {
        createIfMissing: true,
        encrypt: false,
        backup: false,
        autoSync: true,
        kvStoreType: distributedKVStore.KVStoreType.SINGLE_VERSION,
        securityLevel: distributedKVStore.SecurityLevel.S1
      };
      this.kvStore = await kvManager.getKVStore<distributedKVStore.SingleKVStore>('focux_watch_sync', config);
      this.kvStore.on('dataChange', distributedKVStore.SubscribeType.SUBSCRIBE_TYPE_ALL, () => {
        if (!this.writing) {
          this.reloadFromRemote();
        }
      });
      await this.reloadFromRemote();
    } catch (error) {
      this.statusText = this.tx('sync_fail');
    }
  }

  private parseBundle(text: string): TaskSyncBundle {
    const parsed = JSON.parse(text) as Object;
    if (Array.isArray(parsed)) {
      return { updatedAt: 0, tasks: this.normalizeList(parsed as WearTask[]) };
    }
    const obj = parsed as TaskSyncBundle;
    const tasks = Array.isArray(obj.tasks) ? this.normalizeList(obj.tasks) : [];
    const updatedAt = typeof obj.updatedAt === 'number' ? obj.updatedAt : 0;
    return { updatedAt, tasks };
  }

  private normalizeList(list: WearTask[]): WearTask[] {
    return list.map((t: WearTask) => this.normalizeTask(t));
  }

  private normalizeTask(t: WearTask): WearTask {
    const priority = t.priority === 1 || t.priority === 3 ? t.priority : 2;
    return {
      id: t.id && t.id.length > 0 ? t.id : `wear_${Date.now()}`,
      title: t.title ?? '',
      content: t.content ?? '',
      studyMinutes: typeof t.studyMinutes === 'number' ? t.studyMinutes : 25,
      studyMethod: t.studyMethod ?? 'reading',
      priority: priority,
      basePriority: typeof t.basePriority === 'number' ? t.basePriority : priority,
      completed: !!t.completed,
      createdAt: typeof t.createdAt === 'number' ? t.createdAt : Date.now(),
      dueAt: t.dueAt,
      insight: t.insight ?? ''
    };
  }

  private async reloadFromRemote(): Promise<void> {
    if (!this.kvStore) {
      return;
    }
    try {
      const value = await this.kvStore.get('tasks_sync');
      let text = '';
      if (typeof value === 'string') {
        text = value;
      }
      if (text.length === 0) {
        this.statusText = this.tasks.length > 0 ? this.tx('sync_ok') : this.tx('sync_empty');
        return;
      }
      const bundle = this.parseBundle(text);
      if (bundle.updatedAt >= this.localStamp) {
        this.applyTaskList(bundle.tasks);
        this.localStamp = bundle.updatedAt;
        await this.persistLocal(bundle.tasks, bundle.updatedAt);
        this.statusText = this.tasks.length > 0 ? this.tx('sync_ok') : this.tx('sync_empty');
      }
      try {
        const langVal = await this.kvStore.get('language_sync');
        if (typeof langVal === 'number') {
          this.lang = langVal === 1 ? 1 : 0;
          if (this.pref) {
            await this.pref.put('language', this.lang);
            await this.pref.flush();
          }
        }
      } catch (_e) {
        // optional
      }
    } catch (error) {
      this.statusText = this.tx('sync_empty');
    }
  }

  private async persistLocal(list: WearTask[], stamp: number): Promise<void> {
    if (!this.pref) {
      return;
    }
    try {
      await this.pref.put('tasks_json', JSON.stringify(list));
      await this.pref.put('tasks_stamp', stamp);
      await this.pref.flush();
    } catch (_e) {
      // ignore
    }
  }

  private async pushTasks(list: WearTask[]): Promise<void> {
    const stamp = Date.now();
    this.applyTaskList(list);
    this.localStamp = stamp;
    await this.persistLocal(list, stamp);
    if (!this.kvStore) {
      this.statusText = this.tx('saved');
      return;
    }
    this.writing = true;
    try {
      const bundle: TaskSyncBundle = { updatedAt: stamp, tasks: list };
      await this.kvStore.put('tasks_sync', JSON.stringify(bundle));
      this.statusText = this.tx('saved');
    } catch (_e) {
      this.statusText = this.tx('sync_fail');
    } finally {
      setTimeout(() => {
        this.writing = false;
      }, 400);
    }
  }

  private openFocus(): void {
    this.getUIContext().getRouter().pushUrl({ url: 'pages/FocusPage' }).catch(() => {
    });
  }

  private openSettings(): void {
    this.getUIContext().getRouter().pushUrl({ url: 'pages/SettingsPage' }).catch(() => {
    });
  }

  private startCreate(): void {
    this.isNew = true;
    this.editId = `wear_${Date.now()}`;
    this.editTitle = '';
    this.editPriority = 2;
    this.editDueOffsetDays = 1;
    this.editing = true;
  }

  private startEdit(task: WearTask): void {
    this.isNew = false;
    this.editId = task.id;
    this.editTitle = task.title;
    this.editPriority = task.priority === 1 || task.priority === 3 ? task.priority : 2;
    if (task.dueAt !== undefined) {
      const days = Math.max(0, Math.round((task.dueAt - Date.now()) / (24 * 60 * 60 * 1000)));
      this.editDueOffsetDays = days <= 1 ? 1 : (days <= 3 ? 3 : 7);
    } else {
      this.editDueOffsetDays = 1;
    }
    this.editing = true;
  }

  private cyclePriority(): void {
    if (this.editPriority === 1) {
      this.editPriority = 2;
    } else if (this.editPriority === 2) {
      this.editPriority = 3;
    } else {
      this.editPriority = 1;
    }
  }

  private cycleDue(): void {
    if (this.editDueOffsetDays === 1) {
      this.editDueOffsetDays = 3;
    } else if (this.editDueOffsetDays === 3) {
      this.editDueOffsetDays = 7;
    } else {
      this.editDueOffsetDays = 1;
    }
  }

  private async saveEdit(): Promise<void> {
    const title = this.editTitle.trim().length > 0 ? this.editTitle.trim() : (this.lang === 1 ? '未命名' : 'Untitled');
    const dueAt = Date.now() + this.editDueOffsetDays * 24 * 60 * 60 * 1000;
    let next: WearTask[] = [...this.allTasks];
    if (this.isNew) {
      const created: WearTask = {
        id: this.editId,
        title: title,
        content: '',
        studyMinutes: 25,
        studyMethod: 'reading',
        priority: this.editPriority,
        basePriority: this.editPriority,
        completed: false,
        createdAt: Date.now(),
        dueAt: dueAt,
        insight: ''
      };
      next = [created, ...next];
    } else {
      next = next.map((t: WearTask) => {
        if (t.id !== this.editId) {
          return t;
        }
        return {
          id: t.id,
          title: title,
          content: t.content ?? '',
          studyMinutes: t.studyMinutes ?? 25,
          studyMethod: t.studyMethod ?? 'reading',
          priority: this.editPriority,
          basePriority: this.editPriority,
          completed: t.completed,
          createdAt: t.createdAt,
          dueAt: dueAt,
          insight: t.insight ?? ''
        };
      });
    }
    this.editing = false;
    await this.pushTasks(next);
  }

  private async markDone(): Promise<void> {
    if (this.isNew) {
      this.editing = false;
      return;
    }
    const next = this.allTasks.map((t: WearTask) => {
      if (t.id !== this.editId) {
        return t;
      }
      return {
        id: t.id,
        title: t.title,
        content: t.content ?? '',
        studyMinutes: t.studyMinutes ?? 25,
        studyMethod: t.studyMethod ?? 'reading',
        priority: t.priority,
        basePriority: t.basePriority ?? t.priority,
        completed: true,
        createdAt: t.createdAt,
        dueAt: t.dueAt,
        insight: t.insight ?? ''
      };
    });
    this.editing = false;
    await this.pushTasks(next);
  }

  private async deleteEdit(): Promise<void> {
    if (this.isNew) {
      this.editing = false;
      return;
    }
    const next = this.allTasks.filter((t: WearTask) => t.id !== this.editId);
    this.editing = false;
    await this.pushTasks(next);
  }

  @Builder
  homePage() {
    Column({ space: 6 }) {
      Text(this.tx('title'))
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor('#C8C8C8')
        .textAlign(TextAlign.Center)
        .width('100%')

      Text(this.clockText)
        .fontSize(34)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .textAlign(TextAlign.Center)
        .width('100%')

      Text(`${this.bpm} bpm`)
        .fontSize(11)
        .fontColor('#A8A8A8')
        .textAlign(TextAlign.Center)
        .width('100%')

      Button(this.tx('focus'))
        .width(88)
        .height(88)
        .borderRadius(44)
        .fontSize(13)
        .fontColor(Color.White)
        .backgroundColor('#4A4A4A')
        .border({ width: 1.5, color: '#E8E8E8' })
        .margin({ top: 4 })
        .onClick(() => this.openFocus())

      Text(this.statusText)
        .fontSize(9)
        .fontColor('#888888')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .textAlign(TextAlign.Center)
        .width('100%')
        .margin({ top: 2 })
    }
    .width(this.contentW())
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  tasksPage() {
    Column({ space: 4 }) {
      if (this.editing) {
        this.editorPanel()
      } else {
        Row() {
          Text(`${this.tx('tasks')} ${this.tasks.length}`)
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
          Text('+')
            .width(28)
            .height(28)
            .borderRadius(14)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .textAlign(TextAlign.Center)
            .backgroundColor('#555555')
            .onClick(() => this.startCreate())
        }
        .width(this.contentW())

        List({ space: 4 }) {
          ForEach(this.tasks, (task: WearTask) => {
            ListItem() {
              Row({ space: 6 }) {
                Text(task.title)
                  .fontSize(11)
                  .fontColor(Color.White)
                  .layoutWeight(1)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(`P${task.priority}`)
                  .fontSize(9)
                  .fontColor('#CFCFCF')
              }
              .width('100%')
              .height(32)
              .padding({ left: 10, right: 10 })
              .backgroundColor('#3A3A3A')
              .borderRadius(16)
              .onClick(() => this.startEdit(task))
            }
          }, (task: WearTask) => task.id)

          if (this.tasks.length === 0) {
            ListItem() {
              Text(this.tx('sync_empty'))
                .fontSize(11)
                .fontColor('#888888')
                .width('100%')
                .textAlign(TextAlign.Center)
                .padding({ top: 16, bottom: 16 })
            }
          }
        }
        .width(this.contentW())
        .layoutWeight(1)
        .edgeEffect(EdgeEffect.Spring)
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
    .padding({ top: 2 })
  }

  @Builder
  editorPanel() {
    Scroll() {
      Column({ space: 5 }) {
        Text(this.isNew ? this.tx('add') : this.tx('edit'))
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .width('100%')
          .textAlign(TextAlign.Center)

        TextInput({ text: this.editTitle, placeholder: this.tx('title_hint') })
          .width('100%')
          .height(30)
          .fontSize(11)
          .fontColor(Color.White)
          .placeholderColor('#777777')
          .backgroundColor('#3A3A3A')
          .borderRadius(15)
          .padding({ left: 10, right: 10 })
          .onChange((v: string) => {
            this.editTitle = v;
          })

        Row({ space: 6 }) {
          Button(`P${this.editPriority}`)
            .layoutWeight(1)
            .height(28)
            .borderRadius(14)
            .fontSize(11)
            .fontColor(Color.White)
            .backgroundColor('#555555')
            .onClick(() => this.cyclePriority())
          Button(`${this.editDueOffsetDays}d`)
            .layoutWeight(1)
            .height(28)
            .borderRadius(14)
            .fontSize(11)
            .fontColor(Color.White)
            .backgroundColor('#555555')
            .onClick(() => this.cycleDue())
        }
        .width('100%')

        Row({ space: 6 }) {
          Button(this.tx('save'))
            .layoutWeight(1)
            .height(28)
            .borderRadius(14)
            .fontSize(11)
            .fontColor(Color.White)
            .backgroundColor('#4A7C59')
            .onClick(() => {
              this.saveEdit();
            })
          Button(this.tx('cancel'))
            .layoutWeight(1)
            .height(28)
            .borderRadius(14)
            .fontSize(11)
            .fontColor(Color.White)
            .backgroundColor('#555555')
            .onClick(() => {
              this.editing = false;
            })
        }
        .width('100%')

        if (!this.isNew) {
          Row({ space: 6 }) {
            Button(this.tx('done'))
              .layoutWeight(1)
              .height(26)
              .borderRadius(13)
              .fontSize(10)
              .fontColor(Color.White)
              .backgroundColor('#555555')
              .onClick(() => {
                this.markDone();
              })
            Button(this.tx('delete'))
              .layoutWeight(1)
              .height(26)
              .borderRadius(13)
              .fontSize(10)
              .fontColor(Color.White)
              .backgroundColor('#7A3A3A')
              .onClick(() => {
                this.deleteEdit();
              })
          }
          .width('100%')
        }
      }
      .width(this.contentW())
      .padding({ bottom: 8 })
    }
    .width('100%')
    .layoutWeight(1)
    .scrollBar(BarState.Off)
    .align(Alignment.Top)
  }

  @Builder
  pageDots() {
    Row({ space: 8 }) {
      Circle({ width: 7, height: 7 })
        .fill(this.currentIndex === 0 ? Color.White : '#666666')
        .onClick(() => {
          this.currentIndex = 0;
          this.swiperController.changeIndex(0, true);
        })
      Circle({ width: 7, height: 7 })
        .fill(this.currentIndex === 1 ? Color.White : '#666666')
        .onClick(() => {
          this.currentIndex = 1;
          this.swiperController.changeIndex(1, true);
        })
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height(18)
  }

  build() {
    Column({ space: 2 }) {
      // Settings at top-center (round watch safe area)
      Text('⚙')
        .fontSize(16)
        .fontColor(Color.White)
        .width(28)
        .height(28)
        .borderRadius(14)
        .textAlign(TextAlign.Center)
        .backgroundColor('#444444')
        .alignSelf(ItemAlign.Center)
        .onClick(() => this.openSettings())

      Swiper(this.swiperController) {
        Column() {
          this.homePage()
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)

        Column() {
          this.tasksPage()
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      }
      .layoutWeight(1)
      .index(this.currentIndex)
      .indicator(false)
      .loop(false)
      .vertical(false)
      .onChange((index: number) => {
        this.currentIndex = index;
        if (!this.editing) {
          this.reloadFromRemote();
        }
      })

      this.pageDots()
    }
    .width('100%')
    .height('100%')
    .padding({
      left: SAFE_H,
      right: SAFE_H,
      top: Math.max(10, SAFE_V_TOP - 8),
      bottom: SAFE_V_BOT
    })
    .backgroundColor('#2A2A2A')
    .onAreaChange((_o: Area, area: Area) => {
      const w = Number(area.width);
      const h = Number(area.height);
      const side = Math.min(
        Number.isNaN(w) ? 200 : w,
        Number.isNaN(h) ? 200 : h
      );
      if (side > 0) {
        this.pageSize = side;
      }
    })
  }
}
