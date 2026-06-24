import { common } from '@kit.AbilityKit';
import { BlePowerState, GuardConfig, GuardDiagnosticSeverity, GuardRunState, GuardSnapshot } from '../model/GuardModels';
import { GuardCenter } from '../services/GuardCenter';
import { isStartGuardAction, isStopGuardAction, setWidgetActionHandler } from '../services/WidgetActionStore';

enum LogFilter {
  ALL = 'all',
  ERROR = 'error',
  SYSTEM = 'system',
  BLE = 'BLE',
  BACKGROUND = 'background'
}

@Entry
@Component
struct Index {
  @State snapshot: GuardSnapshot = new GuardSnapshot();
  @State deviceId: string = '';
  @State logFilter: LogFilter = LogFilter.ALL;
  private guardCenter?: GuardCenter;
  private guardCenterReady: boolean = false;
  private pendingWidgetAction: string = '';

  aboutToAppear(): void {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    const config: GuardConfig = new GuardConfig(context, 'com.example.hoble', 'EntryAbility');
    this.guardCenter = new GuardCenter(config);
    this.guardCenter.subscribe((snapshot: GuardSnapshot) => {
      this.snapshot = snapshot;
      this.deviceId = snapshot.deviceId;
      this.tryConsumeWidgetAction();
    });
    setWidgetActionHandler((action: string) => {
      this.pendingWidgetAction = action;
      this.tryConsumeWidgetAction();
    });
    this.guardCenter.initialize().then(() => {
      this.guardCenterReady = true;
      this.tryConsumeWidgetAction();
    }).catch(() => {
      this.guardCenterReady = true;
      this.tryConsumeWidgetAction();
    });
  }

  aboutToDisappear(): void {
    setWidgetActionHandler(null);
    this.guardCenterReady = false;
    this.pendingWidgetAction = '';
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Scroll() {
        Column({ space: 16 }) {
          Text($r('app.string.guard_title'))
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.guard_text_primary'))
            .width('100%')

          Text($r('app.string.guard_limit_notice'))
            .fontSize(14)
            .fontColor($r('app.color.guard_warning'))
            .backgroundColor($r('app.color.guard_warning_background'))
            .borderRadius(12)
            .padding(12)
            .width('100%')

          this.StatusCard()
          this.DiagnosticsCard()
          this.ControlCard()
          this.LogCard()
        }
        .padding({ left: 20, right: 20, top: 20, bottom: 112 })
        .width('100%')
      }
      .height('100%')
      .width('100%')

      this.FloatingGuardButton()
    }
    .height('100%')
    .width('100%')
    .backgroundColor($r('app.color.guard_page_background'))
  }

  @Builder
  private StatusCard() {
    Column({ space: 10 }) {
      this.CardTitle($r('app.string.guard_status_title'))
      this.StatusRows()
      Text(this.snapshot.lastMessage)
        .fontSize(13)
        .fontColor($r('app.color.guard_text_secondary'))
        .width('100%')
    }
    .padding(16)
    .borderRadius(16)
    .backgroundColor($r('app.color.guard_card_background'))
    .width('100%')
  }

  @Builder
  private DiagnosticsCard() {
    Column({ space: 10 }) {
      Row() {
        Text($r('app.string.guard_diagnostics_title'))
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.guard_text_primary'))
        Blank()
        Text(this.snapshot.diagnostics.severity.toString())
          .fontSize(12)
          .fontColor(this.diagnosticTextColor())
          .backgroundColor(this.diagnosticBadgeBackground())
          .borderRadius(8)
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
      }
      .width('100%')

      Text(this.snapshot.diagnostics.summary)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.guard_text_primary'))
        .width('100%')

      Column({ space: 8 }) {
        this.DiagnosticRow($r('app.string.guard_last_exit_reason'), this.snapshot.diagnostics.lastExitReason)
        this.DiagnosticRow($r('app.string.guard_system_kill_count'), `${this.snapshot.diagnostics.systemKillCount}`)
        this.DiagnosticRow($r('app.string.guard_last_system_event'), this.snapshot.diagnostics.lastSystemEvent)
        this.DiagnosticRow($r('app.string.guard_last_background_event'), this.snapshot.diagnostics.lastBackgroundEvent)
      }
      .padding(12)
      .borderRadius(8)
      .backgroundColor($r('app.color.guard_status_item_background'))
      .border({ width: 1, color: $r('app.color.guard_status_item_border') })
      .width('100%')
    }
    .padding(16)
    .borderRadius(16)
    .backgroundColor($r('app.color.guard_card_background'))
    .width('100%')
  }

  @Builder
  private ControlCard() {
    Column({ space: 10 }) {
      this.CardTitle($r('app.string.guard_control_title'))
      Row({ space: 10 }) {
        TextInput({ text: this.deviceId, placeholder: $r('app.string.guard_device_placeholder') })
          .width('62%')
          .onChange((value: string) => {
            this.deviceId = value;
          })
        Button($r('app.string.guard_save_device'))
          .width('34%')
          .height(40)
          .borderRadius(14)
          .onClick(() => {
            this.guardCenter?.saveDeviceId(this.deviceId);
          })
      }
      .width('100%')

      Row({ space: 10 }) {
        Button($r('app.string.guard_request_permission'))
          .width('48%')
          .height(42)
          .borderRadius(14)
          .fontColor($r('app.color.guard_primary'))
          .backgroundColor($r('app.color.guard_primary_soft'))
          .onClick(() => {
            this.guardCenter?.requestPermissions();
          })
        Button($r('app.string.guard_refresh'))
          .width('48%')
          .height(42)
          .borderRadius(14)
          .fontColor($r('app.color.guard_primary'))
          .backgroundColor($r('app.color.guard_primary_soft'))
          .onClick(() => {
            this.guardCenter?.refresh();
          })
      }
      .width('100%')

      Button($r('app.string.guard_copy_pairing_config'))
        .width('100%')
        .height(42)
        .borderRadius(14)
        .fontColor($r('app.color.guard_primary'))
        .backgroundColor($r('app.color.guard_primary_soft'))
        .onClick(() => {
          this.guardCenter?.copyPairingConfig();
        })
    }
    .padding(16)
    .borderRadius(16)
    .backgroundColor($r('app.color.guard_card_background'))
    .width('100%')
  }

  @Builder
  private FloatingGuardButton() {
    Stack({ alignContent: Alignment.Center }) {
      Button(this.isGuardActive() ? $r('app.string.guard_stop') : $r('app.string.guard_start'))
        .width('100%')
        .height(54)
        .borderRadius(22)
        .backgroundColor(this.floatingButtonBackgroundColor())
        .backgroundEffect({
          radius: 18,
          saturation: this.isGuardActive() ? 1.25 : 1.1,
          brightness: this.isGuardActive() ? 0.95 : 1.08,
          color: this.isGuardActive() ? '#26B42318' : '#1F2563EB'
        })
        .foregroundEffect({ radius: 1 })
        .fontWeight(FontWeight.Medium)
        .fontColor(this.floatingButtonTextColor())
        .lightUpEffect(this.isGuardActive() ? 1 : 0.92)
        .shadow({
          radius: 18,
          color: this.isGuardActive() ? '#33B42318' : '#402563EB',
          offsetX: 0,
          offsetY: 8
        })
        .enabled(this.snapshot.runState !== GuardRunState.STARTING && this.snapshot.runState !== GuardRunState.STOPPING)
        .onClick(() => {
          if (this.isGuardActive()) {
            this.guardCenter?.stopGuard();
          } else {
            this.guardCenter?.startGuard();
          }
        })
    }
    .width('100%')
    .padding({ left: 32, right: 32, bottom: 24 })
    .zIndex(2)
  }

  @Builder
  private LogCard() {
    Column({ space: 8 }) {
      this.CardTitle($r('app.string.guard_log_title'))
      Column({ space: 8 }) {
        Row({ space: 8 }) {
          this.LogFilterButton(LogFilter.ALL)
          this.LogFilterButton(LogFilter.ERROR)
          this.LogFilterButton(LogFilter.SYSTEM)
        }
        .width('100%')
        Row({ space: 8 }) {
          this.LogFilterButton(LogFilter.BLE)
          this.LogFilterButton(LogFilter.BACKGROUND)
        }
        .width('100%')
      }
      .width('100%')
      Scroll() {
        Column({ space: 8 }) {
          ForEach(this.filteredLogs(), (item: string) => {
            Text(item)
              .fontSize(12)
              .fontColor($r('app.color.guard_text_secondary'))
              .width('100%')
          }, (item: string) => item)
          if (this.filteredLogs().length === 0) {
            Text($r('app.string.guard_log_empty'))
              .fontSize(12)
              .fontColor($r('app.color.guard_text_secondary'))
              .width('100%')
          }
        }
        .width('100%')
      }
      .height(160)
      .width('100%')
    }
    .padding(16)
    .borderRadius(16)
    .backgroundColor($r('app.color.guard_card_background'))
    .width('100%')
  }

  @Builder
  private DiagnosticRow(label: Resource, value: string) {
    Row({ space: 8 }) {
      Text(label)
        .fontSize(12)
        .fontColor($r('app.color.guard_text_secondary'))
        .width('36%')
      Text(value)
        .fontSize(12)
        .fontColor($r('app.color.guard_text_primary'))
        .width('62%')
    }
    .width('100%')
  }

  @Builder
  private LogFilterButton(filter: LogFilter) {
    Button(this.logFilterText(filter))
      .width(76)
      .height(32)
      .borderRadius(10)
      .fontSize(12)
      .fontColor(this.logFilter === filter ? $r('app.color.guard_filter_active_text') : $r('app.color.guard_primary'))
      .backgroundColor(this.logFilter === filter ? $r('app.color.guard_primary') : $r('app.color.guard_primary_soft'))
      .padding({ left: 8, right: 8 })
      .onClick(() => {
        this.logFilter = filter;
      })
  }

  @Builder
  private CardTitle(title: Resource) {
    Text(title)
      .fontSize(18)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('app.color.guard_text_primary'))
      .width('100%')
  }

  private isGuardActive(): boolean {
    return this.snapshot.runState === GuardRunState.RUNNING ||
      (this.snapshot.advertising && this.snapshot.backgroundRunning);
  }

  private floatingButtonBackgroundColor(): ResourceColor {
    if (this.isGuardActive()) {
      return $r('app.color.guard_diagnostic_critical');
    }
    return $r('app.color.guard_primary');
  }

  private floatingButtonTextColor(): ResourceColor {
    return Color.White;
  }

  private hasGuardResidue(): boolean {
    return this.snapshot.advertising || this.snapshot.backgroundRunning;
  }

  private guardRunStateText(): string {
    if (this.isGuardActive()) {
      return GuardRunState.RUNNING.toString();
    }
    if (this.hasGuardResidue()) {
      return GuardRunState.FAILED.toString();
    }
    return this.snapshot.runState.toString();
  }

  private logFilterText(filter: LogFilter): Resource {
    if (filter === LogFilter.ALL) {
      return $r('app.string.guard_log_filter_all');
    }
    if (filter === LogFilter.ERROR) {
      return $r('app.string.guard_log_filter_error');
    }
    if (filter === LogFilter.SYSTEM) {
      return $r('app.string.guard_log_filter_system');
    }
    if (filter === LogFilter.BLE) {
      return $r('app.string.guard_log_filter_ble');
    }
    return $r('app.string.guard_log_filter_background');
  }

  private filteredLogs(): Array<string> {
    if (this.logFilter === LogFilter.ALL) {
      return this.snapshot.logs;
    }
    const result: Array<string> = [];
    for (let index: number = 0; index < this.snapshot.logs.length; index++) {
      const item: string = this.snapshot.logs[index];
      if (this.logMatchesFilter(item)) {
        result.push(item);
      }
    }
    return result;
  }

  private logMatchesFilter(item: string): boolean {
    if (this.logFilter === LogFilter.ERROR) {
      return item.indexOf('ERROR') >= 0 || item.indexOf('异常') >= 0 || item.indexOf('失败') >= 0 || item.indexOf('暂停') >= 0 || item.indexOf('取消') >= 0;
    }
    if (this.logFilter === LogFilter.SYSTEM) {
      return item.indexOf('系统') >= 0 || item.indexOf('查杀') >= 0 || item.indexOf('退出') >= 0 || item.indexOf('管控') >= 0;
    }
    if (this.logFilter === LogFilter.BLE) {
      return item.indexOf('BLE') >= 0 || item.indexOf('蓝牙') >= 0 || item.indexOf('广播') >= 0;
    }
    if (this.logFilter === LogFilter.BACKGROUND) {
      return item.indexOf('后台') >= 0 || item.indexOf('长时任务') >= 0;
    }
    return true;
  }

  private diagnosticTextColor(): Resource {
    if (this.snapshot.diagnostics.severity === GuardDiagnosticSeverity.CRITICAL) {
      return $r('app.color.guard_diagnostic_critical');
    }
    if (this.snapshot.diagnostics.severity === GuardDiagnosticSeverity.WARNING) {
      return $r('app.color.guard_warning');
    }
    return $r('app.color.guard_primary');
  }

  private diagnosticBadgeBackground(): Resource {
    if (this.snapshot.diagnostics.severity === GuardDiagnosticSeverity.CRITICAL) {
      return $r('app.color.guard_diagnostic_critical_background');
    }
    if (this.snapshot.diagnostics.severity === GuardDiagnosticSeverity.WARNING) {
      return $r('app.color.guard_warning_background');
    }
    return $r('app.color.guard_primary_soft');
  }

  private tryConsumeWidgetAction(): void {
    if (!this.guardCenterReady || this.guardCenter === undefined || this.pendingWidgetAction.length === 0) {
      return;
    }
    if (isStartGuardAction(this.pendingWidgetAction)) {
      this.tryStartGuardFromWidget();
      return;
    }
    if (isStopGuardAction(this.pendingWidgetAction)) {
      this.tryStopGuardFromWidget();
    }
  }

  private tryStartGuardFromWidget(): void {
    if (this.guardCenter === undefined) {
      return;
    }
    if (this.snapshot.runState === GuardRunState.RUNNING ||
      this.snapshot.runState === GuardRunState.STARTING ||
      this.snapshot.runState === GuardRunState.STOPPING) {
      this.pendingWidgetAction = '';
      return;
    }
    this.pendingWidgetAction = '';
    this.guardCenter.startGuard().catch(() => {
    });
  }

  private tryStopGuardFromWidget(): void {
    if (this.guardCenter === undefined) {
      return;
    }
    if (this.snapshot.runState === GuardRunState.STARTING ||
      this.snapshot.runState === GuardRunState.STOPPING) {
      this.pendingWidgetAction = '';
      return;
    }
    this.pendingWidgetAction = '';
    this.guardCenter.stopGuard().catch(() => {
    });
  }

  @Builder
  private StatusRows() {
    Column({ space: 10 }) {
      Row({ space: 10 }) {
        Column({ space: 6 }) {
          Row() {
            Text($r('app.string.guard_run_state'))
              .fontSize(12)
              .fontColor($r('app.color.guard_text_secondary'))
            Blank()
            Text('●')
              .fontSize(12)
              .fontColor(this.isGuardActive() ? $r('app.color.guard_primary') : $r('app.color.guard_text_secondary'))
          }
          .width('100%')
          Text(this.guardRunStateText())
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.guard_text_primary'))
            .width('100%')
        }
        .padding({ left: 12, right: 12, top: 10, bottom: 10 })
        .borderRadius(8)
        .backgroundColor(this.isGuardActive() ? $r('app.color.guard_status_item_active_background') : $r('app.color.guard_status_item_background'))
        .border({ width: 1, color: $r('app.color.guard_status_item_border') })
        .width('48%')

        Column({ space: 6 }) {
          Row() {
            Text($r('app.string.guard_ble_state'))
              .fontSize(12)
              .fontColor($r('app.color.guard_text_secondary'))
            Blank()
            Text('●')
              .fontSize(12)
              .fontColor(this.snapshot.blePowerState === BlePowerState.ON ? $r('app.color.guard_primary') : $r('app.color.guard_text_secondary'))
          }
          .width('100%')
          Text(this.snapshot.blePowerState.toString())
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.guard_text_primary'))
            .width('100%')
        }
        .padding({ left: 12, right: 12, top: 10, bottom: 10 })
        .borderRadius(8)
        .backgroundColor(this.snapshot.blePowerState === BlePowerState.ON ? $r('app.color.guard_status_item_active_background') : $r('app.color.guard_status_item_background'))
        .border({ width: 1, color: $r('app.color.guard_status_item_border') })
        .width('48%')
      }
      .width('100%')

      Row({ space: 10 }) {
        Column({ space: 6 }) {
          Row() {
            Text($r('app.string.guard_permission_state'))
              .fontSize(12)
              .fontColor($r('app.color.guard_text_secondary'))
            Blank()
            Text('●')
              .fontSize(12)
              .fontColor(this.snapshot.permissionGranted ? $r('app.color.guard_primary') : $r('app.color.guard_text_secondary'))
          }
          .width('100%')
          Text(this.snapshot.permissionGranted ? '已授权' : '未确认')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.guard_text_primary'))
            .width('100%')
        }
        .padding({ left: 12, right: 12, top: 10, bottom: 10 })
        .borderRadius(8)
        .backgroundColor(this.snapshot.permissionGranted ? $r('app.color.guard_status_item_active_background') : $r('app.color.guard_status_item_background'))
        .border({ width: 1, color: $r('app.color.guard_status_item_border') })
        .width('48%')

        Column({ space: 6 }) {
          Row() {
            Text($r('app.string.guard_advertising_state'))
              .fontSize(12)
              .fontColor($r('app.color.guard_text_secondary'))
            Blank()
            Text('●')
              .fontSize(12)
              .fontColor(this.snapshot.advertising ? $r('app.color.guard_primary') : $r('app.color.guard_text_secondary'))
          }
          .width('100%')
          Text(this.snapshot.advertising ? '广播中' : '未广播')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.guard_text_primary'))
            .width('100%')
        }
        .padding({ left: 12, right: 12, top: 10, bottom: 10 })
        .borderRadius(8)
        .backgroundColor(this.snapshot.advertising ? $r('app.color.guard_status_item_active_background') : $r('app.color.guard_status_item_background'))
        .border({ width: 1, color: $r('app.color.guard_status_item_border') })
        .width('48%')
      }
      .width('100%')

      Column({ space: 6 }) {
        Row() {
          Text($r('app.string.guard_background_state'))
            .fontSize(12)
            .fontColor($r('app.color.guard_text_secondary'))
          Blank()
          Text('●')
            .fontSize(12)
            .fontColor(this.snapshot.backgroundRunning ? $r('app.color.guard_primary') : $r('app.color.guard_text_secondary'))
        }
        .width('100%')
        Text(this.snapshot.backgroundRunning ? '长时任务运行中' : '未运行')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.guard_text_primary'))
          .width('100%')
      }
      .padding({ left: 12, right: 12, top: 10, bottom: 10 })
      .borderRadius(8)
      .backgroundColor(this.snapshot.backgroundRunning ? $r('app.color.guard_status_item_active_background') : $r('app.color.guard_status_item_background'))
      .border({ width: 1, color: $r('app.color.guard_status_item_border') })
      .width('100%')
    }
    .width('100%')
  }
}
