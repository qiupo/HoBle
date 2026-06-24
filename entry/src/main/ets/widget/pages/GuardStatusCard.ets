let storage: LocalStorage = new LocalStorage();

enum StatusPanelSlot {
  TopStart = 'topStart',
  TopEnd = 'topEnd',
  BottomStart = 'bottomStart',
  BottomEnd = 'bottomEnd'
}

@Entry(storage)
@Component
struct GuardStatusCard {
  @LocalStorageProp('enabledText') enabledText: string = '等待同步';
  @LocalStorageProp('buttonText') buttonText: string = '启动守护';
  @LocalStorageProp('bleState') bleState: string = '待刷新';
  @LocalStorageProp('advertisingText') advertisingText: string = '待刷新';
  @LocalStorageProp('backgroundText') backgroundText: string = '待刷新';
  @LocalStorageProp('permissionText') permissionText: string = '待刷新';
  @LocalStorageProp('lastMessage') lastMessage: string = '点击按钮启动守护并刷新状态';
  @LocalStorageProp('updatedAt') updatedAt: string = '未同步';
  @LocalStorageProp('statusTone') statusTone: string = 'idle';
  private readonly startAction: string = 'start_guard';
  private readonly stopAction: string = 'stop_guard';

  build() {
    Stack() {
      Column() {
        Row() {
          this.StatusPanel('蓝牙', this.bleState === '蓝牙开启', StatusPanelSlot.TopStart)
          Blank()
          this.StatusPanel('广播', this.advertisingText === '广播中', StatusPanelSlot.TopEnd)
        }
        .width('100%')

        Blank()

        Row() {
          this.StatusPanel('后台', this.backgroundText === '后台运行中', StatusPanelSlot.BottomStart)
          Blank()
          this.StatusPanel('权限', this.permissionText === '权限已授权', StatusPanelSlot.BottomEnd)
        }
        .width('100%')
      }
      .width(132)
      .height(132)
      .zIndex(1)
      .align(Alignment.Center)

      FormLink({
        action: 'message',
        params: {
          action: this.isRunning() ? this.stopAction : this.startAction
        }
      }) {
        Row() {
          Text(this.centerButtonText())
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.buttonTextColor())
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width(76)
        .height(76)
        .justifyContent(FlexAlign.Center)
        .borderRadius(38)
        .backgroundColor(this.buttonColor())
        .backgroundBlurStyle(BlurStyle.COMPONENT_THIN)
        .border({ width: 3, color: $r('app.color.guard_card_background') })
        .shadow({ radius: 20, color: '#402563EB', offsetX: 0, offsetY: 6 })
      }
      .zIndex(2)
      .align(Alignment.Center)
    }
    .alignContent(Alignment.Center)
    .width('100%')
    .height('100%')
    .padding(12)
    .borderRadius(16)
    .backgroundColor($r('app.color.guard_card_background'))
    .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THIN)
  }

  @Builder
  private StatusPanel(label: string, active: boolean, slot: StatusPanelSlot) {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width(64)
        .height(64)
        .borderRadius(16)
        .backgroundColor(this.pillBackground(active))
        .border({ width: 1, color: this.pillBorderColor(active) })

      Text(label)
        .width(24)
        .height(16)
        .fontSize(10)
        .fontWeight(FontWeight.Medium)
        .fontColor(active ? $r('app.color.guard_success') : $r('app.color.guard_diagnostic_critical'))
        .maxLines(1)
        .textAlign(TextAlign.Center)
        .position(this.labelPosition(slot))

      Text(active ? '✓' : '✕')
        .width(16)
        .height(16)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(active ? $r('app.color.guard_success') : $r('app.color.guard_diagnostic_critical'))
        .textAlign(TextAlign.Center)
        .position(this.markPosition(slot))
    }
    .width(64)
    .height(64)
  }

  private buttonColor(): ResourceColor {
    if (this.statusTone === 'error') {
      return $r('app.color.guard_diagnostic_critical');
    }
    if (this.statusTone === 'pending') {
      return $r('app.color.guard_warning');
    }
    if (this.statusTone === 'running') {
      return $r('app.color.guard_diagnostic_critical');
    }
    return $r('app.color.guard_primary');
  }

  private buttonTextColor(): ResourceColor {
    if (this.statusTone === 'pending') {
      return $r('app.color.guard_text_primary');
    }
    return Color.White;
  }

  private pillBackground(active: boolean): ResourceColor {
    if (active) {
      return $r('app.color.guard_widget_status_success_background');
    }
    return $r('app.color.guard_widget_status_error_background');
  }

  private pillBorderColor(active: boolean): ResourceColor {
    if (active) {
      return $r('app.color.guard_widget_status_success_border');
    }
    return $r('app.color.guard_widget_status_error_border');
  }

  private labelPosition(slot: StatusPanelSlot): Position {
    if (slot === StatusPanelSlot.TopStart) {
      return { x: 10, y: 10 };
    }
    if (slot === StatusPanelSlot.TopEnd) {
      return { x: 18, y: 10 };
    }
    if (slot === StatusPanelSlot.BottomStart) {
      return { x: 10, y: 40 };
    }
    return { x: 18, y: 40 };
  }

  private markPosition(slot: StatusPanelSlot): Position {
    if (slot === StatusPanelSlot.TopStart) {
      return { x: 39, y: 8 };
    }
    if (slot === StatusPanelSlot.TopEnd) {
      return { x: 45, y: 8 };
    }
    if (slot === StatusPanelSlot.BottomStart) {
      return { x: 39, y: 38 };
    }
    return { x: 45, y: 38 };
  }

  private centerButtonText(): string {
    if (this.isRunning()) {
      return '停止守护';
    }
    return this.buttonText;
  }

  private isRunning(): boolean {
    return this.statusTone === 'running';
  }
}
