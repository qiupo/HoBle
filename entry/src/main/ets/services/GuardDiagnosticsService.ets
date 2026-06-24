import { AbilityConstant } from '@kit.AbilityKit';
import { hiAppEvent } from '@kit.PerformanceAnalysisKit';
import { GuardDiagnostics, GuardDiagnosticSeverity } from '../model/GuardModels';

type DiagnosticsListener = (diagnostics: GuardDiagnostics, message: string) => void;

const WATCHER_NAME: string = 'hobleGuardWatcher';

export class GuardDiagnosticsService {
  private diagnostics: GuardDiagnostics = new GuardDiagnostics();
  private listener?: DiagnosticsListener;
  private subscribed: boolean = false;

  setListener(listener: DiagnosticsListener): void {
    this.listener = listener;
  }

  snapshot(): GuardDiagnostics {
    return this.cloneDiagnostics();
  }

  applyLaunchParam(launchParam: AbilityConstant.LaunchParam | null): void {
    if (launchParam === null) {
      return;
    }
    this.diagnostics.lastExitReason = this.describeLastExitReason(launchParam.lastExitReason);
    this.diagnostics.lastExitMessage = launchParam.lastExitMessage;
    this.refreshSeverity();
    this.refreshSummary();
  }

  startSystemEventWatch(): void {
    if (this.subscribed) {
      return;
    }
    try {
      const filter: hiAppEvent.AppEventFilter = {
        domain: hiAppEvent.domain.OS,
        names: [hiAppEvent.event.APP_KILLED]
      };
      const watcher: hiAppEvent.Watcher = {
        name: WATCHER_NAME,
        appEventFilters: [filter],
        onReceive: (domain: string, appEventGroups: Array<hiAppEvent.AppEventGroup>): void => {
          this.handleSystemEvents(domain, appEventGroups);
        }
      };
      hiAppEvent.addWatcher(watcher);
      this.subscribed = true;
      this.notify('系统查杀事件监听已启用');
    } catch (err) {
      this.diagnostics.lastSystemEvent = `系统查杀事件监听不可用：${this.formatError(err)}`;
      this.refreshSeverity();
      this.refreshSummary();
      this.notify('系统查杀事件监听不可用');
    }
  }

  recordBackgroundEvent(message: string, critical: boolean): void {
    this.diagnostics.backgroundEventCount += 1;
    this.diagnostics.lastBackgroundEvent = message;
    if (critical && this.diagnostics.severity !== GuardDiagnosticSeverity.CRITICAL) {
      this.diagnostics.severity = GuardDiagnosticSeverity.WARNING;
    }
    this.refreshSummary();
    this.notify(message);
  }

  recordGuardResidue(advertising: boolean, backgroundRunning: boolean): void {
    if (advertising === backgroundRunning) {
      return;
    }
    this.diagnostics.backgroundEventCount += 1;
    if (advertising) {
      this.diagnostics.lastBackgroundEvent = 'BLE 广播仍在，但后台长时任务未运行';
    } else {
      this.diagnostics.lastBackgroundEvent = '后台长时任务仍在，但 BLE 广播未运行';
    }
    if (this.diagnostics.severity !== GuardDiagnosticSeverity.CRITICAL) {
      this.diagnostics.severity = GuardDiagnosticSeverity.WARNING;
    }
    this.refreshSummary();
  }

  recordClearRuntimeResidue(): void {
    if (this.diagnostics.systemKillCount > 0) {
      return;
    }
    this.refreshSeverity();
    this.refreshSummary();
  }

  private handleSystemEvents(domain: string, appEventGroups: Array<hiAppEvent.AppEventGroup>): void {
    if (domain !== hiAppEvent.domain.OS) {
      return;
    }
    for (let groupIndex: number = 0; groupIndex < appEventGroups.length; groupIndex++) {
      const group: hiAppEvent.AppEventGroup = appEventGroups[groupIndex];
      if (group.name !== hiAppEvent.event.APP_KILLED) {
        continue;
      }
      this.diagnostics.systemKillCount += group.appEventInfos.length;
      this.diagnostics.lastSystemEvent = `收到系统查杀事件 ${group.appEventInfos.length} 条`;
      this.diagnostics.severity = GuardDiagnosticSeverity.CRITICAL;
      this.refreshSummary();
      this.notify(this.diagnostics.lastSystemEvent);
    }
  }

  private describeLastExitReason(reason: AbilityConstant.LastExitReason): string {
    if (reason === AbilityConstant.LastExitReason.UNKNOWN) {
      return '未记录';
    }
    if (reason === AbilityConstant.LastExitReason.NORMAL) {
      return '用户正常关闭';
    }
    if (reason === AbilityConstant.LastExitReason.CPP_CRASH) {
      return 'Native 异常退出';
    }
    if (reason === AbilityConstant.LastExitReason.JS_ERROR) {
      return 'ArkTS/JS 异常退出';
    }
    if (reason === AbilityConstant.LastExitReason.APP_FREEZE) {
      return '应用无响应';
    }
    if (reason === AbilityConstant.LastExitReason.PERFORMANCE_CONTROL) {
      return '系统性能管控';
    }
    if (reason === AbilityConstant.LastExitReason.RESOURCE_CONTROL) {
      return '系统资源管控';
    }
    if (reason === AbilityConstant.LastExitReason.UPGRADE) {
      return '应用升级';
    }
    if (reason === AbilityConstant.LastExitReason.USER_REQUEST) {
      return '多任务/用户清理';
    }
    if (reason === AbilityConstant.LastExitReason.SIGNAL) {
      return '系统信号终止';
    }
    return '其他异常退出';
  }

  private refreshSeverity(): void {
    if (this.diagnostics.systemKillCount > 0) {
      this.diagnostics.severity = GuardDiagnosticSeverity.CRITICAL;
      return;
    }
    if (this.diagnostics.lastExitReason === '系统资源管控' ||
      this.diagnostics.lastExitReason === '系统性能管控' ||
      this.diagnostics.lastExitReason === '系统信号终止' ||
      this.diagnostics.lastExitReason === '应用无响应' ||
      this.diagnostics.lastExitReason === 'ArkTS/JS 异常退出' ||
      this.diagnostics.lastExitReason === 'Native 异常退出') {
      this.diagnostics.severity = GuardDiagnosticSeverity.CRITICAL;
      return;
    }
    if (this.diagnostics.lastExitReason === '多任务/用户清理') {
      this.diagnostics.severity = GuardDiagnosticSeverity.WARNING;
      return;
    }
    this.diagnostics.severity = GuardDiagnosticSeverity.NORMAL;
  }

  private refreshSummary(): void {
    if (this.diagnostics.systemKillCount > 0) {
      this.diagnostics.summary = `检测到系统查杀事件：${this.diagnostics.lastSystemEvent}`;
      return;
    }
    if (this.diagnostics.lastExitReason !== '未记录' && this.diagnostics.lastExitReason !== '用户正常关闭') {
      if (this.diagnostics.lastExitMessage.length > 0) {
        this.diagnostics.summary = `上次退出：${this.diagnostics.lastExitReason}（${this.diagnostics.lastExitMessage}）`;
        return;
      }
      this.diagnostics.summary = `上次退出：${this.diagnostics.lastExitReason}`;
      return;
    }
    if (this.diagnostics.backgroundEventCount > 0) {
      this.diagnostics.summary = `最近后台事件：${this.diagnostics.lastBackgroundEvent}`;
      return;
    }
    this.diagnostics.summary = '暂无系统异常记录';
  }

  private notify(message: string): void {
    if (this.listener === undefined) {
      return;
    }
    this.listener(this.cloneDiagnostics(), message);
  }

  private cloneDiagnostics(): GuardDiagnostics {
    const result: GuardDiagnostics = new GuardDiagnostics();
    result.summary = this.diagnostics.summary;
    result.lastExitReason = this.diagnostics.lastExitReason;
    result.lastExitMessage = this.diagnostics.lastExitMessage;
    result.systemKillCount = this.diagnostics.systemKillCount;
    result.lastSystemEvent = this.diagnostics.lastSystemEvent;
    result.backgroundEventCount = this.diagnostics.backgroundEventCount;
    result.lastBackgroundEvent = this.diagnostics.lastBackgroundEvent;
    result.severity = this.diagnostics.severity;
    return result;
  }

  private formatError(err: Object): string {
    if (err instanceof Error) {
      return err.message;
    }
    return JSON.stringify(err);
  }
}
