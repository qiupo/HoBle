let storage: LocalStorage = new LocalStorage();

@Entry(storage)
@Component
struct GuardStatusCard {
  @LocalStorageProp('enabledText') enabledText: string = '等待同步';
  @LocalStorageProp('buttonText') buttonText: string = '开启守护';
  @LocalStorageProp('bleState') bleState: string = '待刷新';
  @LocalStorageProp('advertisingText') advertisingText: string = '待刷新';
  @LocalStorageProp('backgroundText') backgroundText: string = '待刷新';
  @LocalStorageProp('permissionText') permissionText: string = '待刷新';
  @LocalStorageProp('lastMessage') lastMessage: string = '点击按钮开启守护并刷新状态';
  @LocalStorageProp('updatedAt') updatedAt: string = '未同步';
  @LocalStorageProp('statusTone') statusTone: string = 'idle';
  private readonly startAction: string = 'start_guard';
  private readonly stopAction: string = 'stop_guard';

  build() {
    Stack() {
      Column() {
        Row() {
          this.StatusCard('蓝牙', this.bleState === '蓝牙开启')
          Blank()
          this.StatusCard('广播', this.advertisingText === '广播中')
        }
        .width('100%')

        Blank()

        Row() {
          this.StatusCard('后台', this.backgroundText === '后台运行中')
          Blank()
          this.StatusCard('权限', this.permissionText === '权限已授权')
        }
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .zIndex(1)

      FormLink({
        action: 'message',
        params: {
          action: this.isRunning() ? this.stopAction : this.startAction
        }
      }) {
        Row() {
          Text(this.centerButtonText())
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width(64)
        .height(64)
        .justifyContent(FlexAlign.Center)
        .borderRadius(32)
        .backgroundColor(this.buttonColor())
        .backgroundBlurStyle(BlurStyle.COMPONENT_THIN)
        .shadow({ radius: 22, color: '#4D2563EB', offsetX: 0, offsetY: 7 })
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
  private StatusCard(label: string, active: boolean) {
    Row() {
      Text(label)
        .fontSize(10)
        .fontWeight(FontWeight.Medium)
        .fontColor(active ? $r('app.color.guard_success') : $r('app.color.guard_diagnostic_critical'))
        .maxLines(1)
      Blank()
      Text(active ? '✓' : '✕')
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(active ? $r('app.color.guard_success') : $r('app.color.guard_diagnostic_critical'))
    }
    .width(62)
    .height(34)
    .padding({ left: 9, right: 8 })
    .borderRadius(12)
    .backgroundColor(this.pillBackground(active))
    .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THIN)
    .border({ width: 1, color: this.pillBorderColor(active) })
    .shadow({ radius: 8, color: this.pillShadowColor(active), offsetX: 0, offsetY: 3 })
  }

  private buttonColor(): ResourceColor {
    if (this.statusTone === 'error') {
      return $r('app.color.guard_diagnostic_critical');
    }
    if (this.statusTone === 'pending') {
      return $r('app.color.guard_warning');
    }
    return $r('app.color.guard_primary');
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

  private pillShadowColor(active: boolean): ResourceColor {
    if (active) {
      return '#3316A34A';
    }
    return '#33B42318';
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
