import { common } from '@kit.AbilityKit';

export enum GuardRunState {
  STOPPED = '未启动',
  STARTING = '启动中',
  RUNNING = '运行中',
  STOPPING = '停止中',
  FAILED = '异常'
}

export enum BlePowerState {
  UNKNOWN = '未知',
  OFF = '蓝牙关闭',
  ON = '蓝牙开启'
}

export class GuardSnapshot {
  blePowerState: BlePowerState = BlePowerState.UNKNOWN;
  permissionGranted: boolean = false;
  advertising: boolean = false;
  backgroundRunning: boolean = false;
  runState: GuardRunState = GuardRunState.STOPPED;
  deviceId: string = '';
  lastMessage: string = '等待启动守护';
  logs: Array<string> = [];
}

export class GuardSettings {
  enabled: boolean = false;
  deviceId: string = '';
}

export class GuardConfig {
  context: common.UIAbilityContext;
  bundleName: string;
  abilityName: string;

  constructor(context: common.UIAbilityContext, bundleName: string, abilityName: string) {
    this.context = context;
    this.bundleName = bundleName;
    this.abilityName = abilityName;
  }
}
