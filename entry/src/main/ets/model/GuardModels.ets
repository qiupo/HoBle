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

export enum GuardDiagnosticSeverity {
  NORMAL = '正常',
  WARNING = '注意',
  CRITICAL = '异常'
}

export class GuardDiagnostics {
  summary: string = '暂无系统异常记录';
  lastExitReason: string = '未记录';
  lastExitMessage: string = '';
  systemKillCount: number = 0;
  lastSystemEvent: string = '未收到系统查杀事件';
  backgroundEventCount: number = 0;
  lastBackgroundEvent: string = '暂无后台任务事件';
  severity: GuardDiagnosticSeverity = GuardDiagnosticSeverity.NORMAL;
}

export class GuardSnapshot {
  guardEnabled: boolean = false;
  blePowerState: BlePowerState = BlePowerState.UNKNOWN;
  permissionGranted: boolean = false;
  advertising: boolean = false;
  backgroundRunning: boolean = false;
  runState: GuardRunState = GuardRunState.STOPPED;
  deviceId: string = '';
  lastMessage: string = '等待启动守护';
  diagnostics: GuardDiagnostics = new GuardDiagnostics();
  logs: Array<string> = [];
}

export class GuardSettings {
  enabled: boolean = false;
  deviceId: string = '';
}

export class GuardConfig {
  context: common.Context;
  bundleName: string;
  abilityName: string;

  constructor(context: common.Context, bundleName: string, abilityName: string) {
    this.context = context;
    this.bundleName = bundleName;
    this.abilityName = abilityName;
  }
}
