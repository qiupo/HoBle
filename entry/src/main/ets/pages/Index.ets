import { common } from '@kit.AbilityKit';
import { BlePowerState, GuardConfig, GuardRunState, GuardSnapshot } from '../model/GuardModels';
import { GuardCenter } from '../services/GuardCenter';

@Entry
@Component
struct Index {
  @State snapshot: GuardSnapshot = new GuardSnapshot();
  @State deviceId: string = '';
  private guardCenter?: GuardCenter;

  aboutToAppear(): void {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    const config: GuardConfig = new GuardConfig(context, 'com.example.hoble', 'EntryAbility');
    this.guardCenter = new GuardCenter(config);
    this.guardCenter.subscribe((snapshot: GuardSnapshot) => {
      this.snapshot = snapshot;
      this.deviceId = snapshot.deviceId;
    });
    this.guardCenter.initialize();
  }

  build() {
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
        this.ControlCard()
        this.LogCard()
      }
      .padding(20)
      .width('100%')
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

      Button(this.isGuardActive() ? $r('app.string.guard_stop') : $r('app.string.guard_start'))
        .width('100%')
        .height(48)
        .borderRadius(16)
        .backgroundColor($r('app.color.guard_primary'))
        .fontWeight(FontWeight.Medium)
        .enabled(this.snapshot.runState !== GuardRunState.STARTING && this.snapshot.runState !== GuardRunState.STOPPING)
        .onClick(() => {
          if (this.isGuardActive()) {
            this.guardCenter?.stopGuard();
          } else {
            this.guardCenter?.startGuard();
          }
        })

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
    }
    .padding(16)
    .borderRadius(16)
    .backgroundColor($r('app.color.guard_card_background'))
    .width('100%')
  }

  @Builder
  private LogCard() {
    Column({ space: 8 }) {
      this.CardTitle($r('app.string.guard_log_title'))
      Scroll() {
        Column({ space: 8 }) {
          ForEach(this.snapshot.logs, (item: string) => {
            Text(item)
              .fontSize(12)
              .fontColor($r('app.color.guard_text_secondary'))
              .width('100%')
          }, (item: string) => item)
          if (this.snapshot.logs.length === 0) {
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
  private CardTitle(title: Resource) {
    Text(title)
      .fontSize(18)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('app.color.guard_text_primary'))
      .width('100%')
  }

  private isGuardActive(): boolean {
    return this.snapshot.runState === GuardRunState.RUNNING || this.snapshot.advertising || this.snapshot.backgroundRunning;
  }

  private guardRunStateText(): string {
    return this.isGuardActive() ? GuardRunState.RUNNING.toString() : this.snapshot.runState.toString();
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
