import { pasteboard } from '@kit.BasicServicesKit';
import { BlePowerState, GuardConfig, GuardDiagnostics, GuardDiagnosticSeverity, GuardRunState, GuardSettings, GuardSnapshot } from '../model/GuardModels';
import { LogStore } from '../common/LogStore';
import { BackgroundTaskService } from './BackgroundTaskService';
import { BleAdvertiser } from './BleAdvertiser';
import { GuardDiagnosticsService } from './GuardDiagnosticsService';
import { GuardWidgetStore } from './GuardWidgetStore';
import { getLastLaunchParam } from './LaunchDiagnosticsStore';
import { PermissionService } from './PermissionService';
import { SettingsStore } from './SettingsStore';

type GuardListener = (snapshot: GuardSnapshot) => void;
const MANUFACTURER_ID_TEXT: string = '0x0B1E';

export class GuardCenter {
  private config: GuardConfig;
  private settingsStore: SettingsStore;
  private permissionService: PermissionService;
  private backgroundTaskService: BackgroundTaskService;
  private diagnosticsService: GuardDiagnosticsService = new GuardDiagnosticsService();
  private widgetStore: GuardWidgetStore;
  private advertiser: BleAdvertiser = new BleAdvertiser();
  private logStore: LogStore = new LogStore();
  private snapshot: GuardSnapshot = new GuardSnapshot();
  private listeners: Array<GuardListener> = [];
  private widgetSnapshotQueue: Promise<void> = Promise.resolve();

  constructor(config: GuardConfig) {
    this.config = config;
    this.settingsStore = new SettingsStore(config.context);
    this.permissionService = new PermissionService(config.context);
    this.backgroundTaskService = new BackgroundTaskService(config.context, config.bundleName, config.abilityName);
    this.widgetStore = new GuardWidgetStore(config.context);
    this.advertiser.setStatusListener((advertising: boolean) => {
      this.snapshot.advertising = advertising;
      this.syncRunState();
      this.publish(advertising ? 'BLE 广播已恢复' : 'BLE 广播已停止');
    });
    this.backgroundTaskService.setStatusListener((running: boolean) => {
      this.snapshot.backgroundRunning = running;
      this.syncRunState();
      this.publish(running ? '后台长时任务已恢复' : '后台长时任务已停止');
    });
    this.backgroundTaskService.setEventListener((message: string, critical: boolean) => {
      this.diagnosticsService.recordBackgroundEvent(message, critical);
    });
    this.diagnosticsService.setListener((diagnostics: GuardDiagnostics, message: string) => {
      this.snapshot.diagnostics = diagnostics;
      if (diagnostics.severity === GuardDiagnosticSeverity.CRITICAL) {
        this.logStore.error(message);
      } else if (diagnostics.severity === GuardDiagnosticSeverity.WARNING) {
        this.logStore.warn(message);
      } else {
        this.logStore.info(message);
      }
      this.publish(message);
    });
  }

  subscribe(listener: GuardListener): void {
    this.listeners.push(listener);
    listener(this.cloneSnapshot());
  }

  async initialize(restoreEnabledGuard: boolean = true): Promise<void> {
    const settings: GuardSettings = await this.settingsStore.load();
    this.snapshot.guardEnabled = settings.enabled;
    this.snapshot.deviceId = settings.deviceId;
    this.diagnosticsService.applyLaunchParam(getLastLaunchParam());
    this.diagnosticsService.startSystemEventWatch();
    await this.refreshStatus();
    this.logStartupDiagnostics();
    this.logStore.info('加载守护配置完成');
    this.publish('初始化完成');
    if (restoreEnabledGuard && settings.enabled) {
      await this.startGuard();
    }
  }

  async requestPermissions(): Promise<void> {
    this.publish('正在请求权限');
    try {
      this.snapshot.permissionGranted = await this.permissionService.request();
      if (this.snapshot.permissionGranted) {
        this.logStore.info('权限授权完成');
        this.publish('权限已授权');
      } else {
        const permissionMessage: string = this.buildPermissionMessage();
        this.logStore.warn(`${permissionMessage}。后台广播可能失败`);
        this.publish(permissionMessage);
      }
    } catch (err) {
      this.logStore.error(`权限请求失败：${this.formatError(err)}`);
      this.publish('权限请求失败');
    }
  }

  async startGuard(): Promise<void> {
    this.snapshot.runState = GuardRunState.STARTING;
    this.publish('正在启动 BLE 守护');
    try {
      await this.refreshStatus();
      if (!this.advertiser.isBluetoothOn()) {
        throw new Error('系统蓝牙未开启');
      }
      if (!this.snapshot.permissionGranted) {
        throw new Error(this.buildPermissionMessage());
      }
      await this.advertiser.start(this.snapshot.deviceId);
      this.snapshot.advertising = this.advertiser.isAdvertising();
      await this.backgroundTaskService.start();
      this.snapshot.backgroundRunning = this.backgroundTaskService.isRunning();
      this.syncRunState(true);
      this.logStore.info('BLE 广播与长时任务已启动');
      await this.saveEnabled(true);
      this.publish('守护运行中，锁屏后仍会尽力维持广播');
    } catch (err) {
      this.snapshot.runState = GuardRunState.FAILED;
      const errorMessage: string = this.formatError(err);
      this.logStore.error(`启动失败：${errorMessage}`);
      this.publish(`启动失败：${errorMessage}`);
    }
  }

  async stopGuard(): Promise<void> {
    this.snapshot.runState = GuardRunState.STOPPING;
    this.publish('正在停止 BLE 守护');
    try {
      await this.advertiser.stop();
      await this.backgroundTaskService.stop();
      this.snapshot.advertising = false;
      this.snapshot.backgroundRunning = false;
      this.snapshot.runState = GuardRunState.STOPPED;
      this.logStore.info('BLE 守护已停止');
      await this.saveEnabled(false);
      this.publish('守护已停止');
    } catch (err) {
      this.snapshot.runState = GuardRunState.FAILED;
      this.logStore.error(`停止失败：${this.formatError(err)}`);
      this.publish('停止失败');
    }
  }

  async saveDeviceId(deviceId: string): Promise<void> {
    this.snapshot.deviceId = deviceId;
    await this.saveEnabled(this.snapshot.runState === GuardRunState.RUNNING);
    this.logStore.info(`设备标识已保存：${deviceId}`);
    this.publish('设备标识已保存');
  }

  async refresh(): Promise<void> {
    await this.refreshStatus();
    this.logStore.info(`状态：蓝牙=${this.snapshot.blePowerState} 权限=${this.snapshot.permissionGranted} 广播=${this.snapshot.advertising} 后台=${this.snapshot.backgroundRunning}`);
    this.publish('状态已刷新');
  }

  async copyPairingConfig(): Promise<void> {
    const configText: string = this.buildPairingConfigText();
    try {
      const systemPasteboard: pasteboard.SystemPasteboard = pasteboard.getSystemPasteboard();
      await systemPasteboard.setData(pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, configText));
      this.logStore.info('Mac 端匹配配置已复制');
      this.publish('匹配配置已复制，可粘贴到 Mac 端工具');
    } catch (err) {
      this.logStore.error(`复制匹配配置失败：${this.formatError(err)}`);
      this.publish('复制匹配配置失败');
    }
  }

  private async refreshStatus(): Promise<void> {
    this.refreshBluetoothState();
    this.snapshot.permissionGranted = this.permissionService.hasAll();
    this.snapshot.advertising = this.advertiser.isAdvertising();
    this.snapshot.backgroundRunning = await this.backgroundTaskService.refresh();
    if (this.snapshot.advertising !== this.snapshot.backgroundRunning) {
      this.diagnosticsService.recordGuardResidue(this.snapshot.advertising, this.snapshot.backgroundRunning);
    } else {
      this.diagnosticsService.recordClearRuntimeResidue();
    }
    this.snapshot.diagnostics = this.diagnosticsService.snapshot();
    this.syncRunState();
  }

  private syncRunState(force: boolean = false): void {
    if (!force && (this.snapshot.runState === GuardRunState.STARTING || this.snapshot.runState === GuardRunState.STOPPING)) {
      return;
    }
    if (this.snapshot.advertising && this.snapshot.backgroundRunning) {
      this.snapshot.runState = GuardRunState.RUNNING;
    } else if (this.snapshot.advertising || this.snapshot.backgroundRunning) {
      this.snapshot.runState = GuardRunState.FAILED;
    } else if (this.snapshot.runState === GuardRunState.RUNNING || this.snapshot.runState === GuardRunState.FAILED) {
      this.snapshot.runState = GuardRunState.STOPPED;
    }
  }

  private async saveEnabled(enabled: boolean): Promise<void> {
    const settings: GuardSettings = new GuardSettings();
    settings.enabled = enabled;
    settings.deviceId = this.snapshot.deviceId;
    await this.settingsStore.save(settings);
    this.snapshot.guardEnabled = enabled;
  }

  private refreshBluetoothState(): void {
    this.snapshot.blePowerState = this.advertiser.isBluetoothOn() ? BlePowerState.ON : BlePowerState.OFF;
  }

  private logStartupDiagnostics(): void {
    const diagnostics: GuardDiagnostics = this.diagnosticsService.snapshot();
    if (diagnostics.summary === '暂无系统异常记录') {
      return;
    }
    this.logStore.warn(diagnostics.summary);
  }

  private buildPermissionMessage(): string {
    const missingPermissionText: string = this.permissionService.getMissingPermissionText();
    if (missingPermissionText.indexOf('后台位置') >= 0) {
      return `缺少权限：${missingPermissionText}，请在系统设置中允许后台位置`;
    }
    return `缺少权限：${missingPermissionText}`;
  }

  private buildPairingConfigText(): string {
    return `HoBle Pairing Config\nmanufacturerId=${MANUFACTURER_ID_TEXT}\ndeviceId=${this.snapshot.deviceId}\nmatchRule=manufacturerId + manufacturerValue(deviceId)`;
  }

  private formatError(err: Object): string {
    if (err instanceof Error) {
      return err.message;
    }
    return JSON.stringify(err);
  }

  private publish(message: string): void {
    this.snapshot.lastMessage = message;
    this.snapshot.logs = this.logStore.getLogs();
    const current: GuardSnapshot = this.cloneSnapshot();
    this.persistWidgetSnapshot(current);
    for (let index: number = 0; index < this.listeners.length; index++) {
      this.listeners[index](current);
    }
  }

  private cloneSnapshot(): GuardSnapshot {
    const result: GuardSnapshot = new GuardSnapshot();
    result.guardEnabled = this.snapshot.guardEnabled;
    result.blePowerState = this.snapshot.blePowerState;
    result.permissionGranted = this.snapshot.permissionGranted;
    result.advertising = this.snapshot.advertising;
    result.backgroundRunning = this.snapshot.backgroundRunning;
    result.runState = this.snapshot.runState;
    result.deviceId = this.snapshot.deviceId;
    result.lastMessage = this.snapshot.lastMessage;
    result.diagnostics = this.cloneDiagnostics(this.snapshot.diagnostics);
    result.logs = this.snapshot.logs.slice();
    return result;
  }

  private persistWidgetSnapshot(snapshot: GuardSnapshot): void {
    this.widgetSnapshotQueue = this.widgetSnapshotQueue.then(() => {
      return this.widgetStore.saveSnapshot(snapshot);
    }).catch((err: Object) => {
      this.logStore.warn(`桌面组件状态同步失败：${this.formatError(err)}`);
    });
  }

  private cloneDiagnostics(diagnostics: GuardDiagnostics): GuardDiagnostics {
    const result: GuardDiagnostics = new GuardDiagnostics();
    result.summary = diagnostics.summary;
    result.lastExitReason = diagnostics.lastExitReason;
    result.lastExitMessage = diagnostics.lastExitMessage;
    result.systemKillCount = diagnostics.systemKillCount;
    result.lastSystemEvent = diagnostics.lastSystemEvent;
    result.backgroundEventCount = diagnostics.backgroundEventCount;
    result.lastBackgroundEvent = diagnostics.lastBackgroundEvent;
    result.severity = diagnostics.severity;
    return result;
  }
}
