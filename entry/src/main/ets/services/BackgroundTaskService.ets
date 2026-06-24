import { common, wantAgent } from '@kit.AbilityKit';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { geoLocationManager } from '@kit.LocationKit';

type BackgroundTaskListener = (running: boolean) => void;
type BackgroundTaskEventListener = (message: string, critical: boolean) => void;

export class BackgroundTaskService {
  private context: common.Context;
  private bundleName: string;
  private abilityName: string;
  private running: boolean = false;
  private continuousTaskId: number = 0;
  private statusListener?: BackgroundTaskListener;
  private eventListener?: BackgroundTaskEventListener;
  private locationActive: boolean = false;
  private locationCallback = (_location: geoLocationManager.Location): void => {
  };
  private continuousTaskCancelCallback = (info: backgroundTaskManager.ContinuousTaskCancelInfo): void => {
    if (info.id !== this.continuousTaskId) {
      return;
    }
    this.running = false;
    this.continuousTaskId = 0;
    this.stopLocationWatcher();
    this.eventListener?.(`后台长时任务被系统取消，任务 ID：${info.id}`, true);
    this.statusListener?.(false);
  };
  private continuousTaskSuspendCallback = (info: backgroundTaskManager.ContinuousTaskSuspendInfo): void => {
    if (info.continuousTaskId !== this.continuousTaskId) {
      return;
    }
    this.running = !info.suspendState;
    if (!this.running) {
      this.stopLocationWatcher();
      this.eventListener?.(`后台长时任务已暂停，任务 ID：${info.continuousTaskId}`, true);
    } else {
      this.eventListener?.(`后台长时任务已恢复，任务 ID：${info.continuousTaskId}`, false);
    }
    this.statusListener?.(this.running);
  };
  private continuousTaskActiveCallback = (info: backgroundTaskManager.ContinuousTaskActiveInfo): void => {
    if (info.id !== this.continuousTaskId) {
      return;
    }
    this.running = true;
    this.eventListener?.(`后台长时任务已激活，任务 ID：${info.id}`, false);
    this.statusListener?.(true);
  };

  constructor(context: common.Context, bundleName: string, abilityName: string) {
    this.context = context;
    this.bundleName = bundleName;
    this.abilityName = abilityName;
    this.subscribeSystemEvents();
  }

  setStatusListener(listener: BackgroundTaskListener): void {
    this.statusListener = listener;
  }

  setEventListener(listener: BackgroundTaskEventListener): void {
    this.eventListener = listener;
  }

  async start(): Promise<void> {
    if (this.running) {
      return;
    }
    try {
      const info: wantAgent.WantAgentInfo = {
        wants: [{
          bundleName: this.bundleName,
          abilityName: this.abilityName
        }],
        operationType: wantAgent.OperationType.START_ABILITY,
        requestCode: 1,
        wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
      };
      const agent = await wantAgent.getWantAgent(info);
      const request: backgroundTaskManager.ContinuousTaskRequest = new backgroundTaskManager.ContinuousTaskRequest();
      request.backgroundTaskModes = [
        backgroundTaskManager.BackgroundTaskMode.MODE_BLUETOOTH_INTERACTION,
        backgroundTaskManager.BackgroundTaskMode.MODE_LOCATION
      ];
      request.backgroundTaskSubmodes = [
        backgroundTaskManager.BackgroundTaskSubmode.SUBMODE_NORMAL_NOTIFICATION,
        backgroundTaskManager.BackgroundTaskSubmode.SUBMODE_NORMAL_NOTIFICATION
      ];
      request.wantAgent = agent;
      const notification = await backgroundTaskManager.startBackgroundRunning(this.context, request);
      this.continuousTaskId = notification.continuousTaskId ?? 0;
      this.running = true;
      this.startLocationWatcher();
      this.statusListener?.(true);
    } catch (err) {
      this.running = false;
      this.continuousTaskId = 0;
      this.stopLocationWatcher();
      throw new Error(this.formatError(err));
    }
  }

  async stop(): Promise<void> {
    if (!this.running) {
      this.stopLocationWatcher();
      return;
    }
    await backgroundTaskManager.stopBackgroundRunning(this.context, this.continuousTaskId);
    this.running = false;
    this.continuousTaskId = 0;
    this.stopLocationWatcher();
    this.statusListener?.(false);
  }

  isRunning(): boolean {
    return this.running;
  }

  async refresh(): Promise<boolean> {
    try {
      const tasks = await backgroundTaskManager.getAllContinuousTasks(this.context, true);
      let matchedTaskId: number = 0;
      let matchedRunning: boolean = false;
      for (let index: number = 0; index < tasks.length; index++) {
        const task = tasks[index];
        if (task.abilityName !== this.abilityName && task.wantAgentAbilityName !== this.abilityName) {
          continue;
        }
        if (task.bundleName !== undefined && task.bundleName !== this.bundleName) {
          continue;
        }
        if (task.wantAgentBundleName !== '' && task.wantAgentBundleName !== this.bundleName) {
          continue;
        }
        matchedTaskId = task.continuousTaskId;
        matchedRunning = !task.suspendState;
        break;
      }
      this.continuousTaskId = matchedTaskId;
      this.running = matchedRunning;
      if (this.running) {
        this.startLocationWatcher();
      } else {
        this.stopLocationWatcher();
      }
    } catch (err) {
      this.running = false;
      this.continuousTaskId = 0;
      this.stopLocationWatcher();
    }
    return this.running;
  }

  private subscribeSystemEvents(): void {
    try {
      backgroundTaskManager.on('continuousTaskCancel', this.continuousTaskCancelCallback);
      backgroundTaskManager.on('continuousTaskSuspend', this.continuousTaskSuspendCallback);
      backgroundTaskManager.on('continuousTaskActive', this.continuousTaskActiveCallback);
    } catch (err) {
      // Status still refreshes from getAllContinuousTasks on devices without these callbacks.
    }
  }

  private startLocationWatcher(): void {
    if (this.locationActive) {
      return;
    }
    try {
      const request: geoLocationManager.ContinuousLocationRequest = {
        interval: 300,
        locationScenario: geoLocationManager.PowerConsumptionScenario.LOW_POWER_CONSUMPTION
      };
      geoLocationManager.on('locationChange', request, this.locationCallback);
      this.locationActive = true;
    } catch (err) {
      this.locationActive = false;
    }
  }

  private stopLocationWatcher(): void {
    if (!this.locationActive) {
      return;
    }
    try {
      geoLocationManager.off('locationChange', this.locationCallback);
    } catch (err) {
    }
    this.locationActive = false;
  }

  private formatError(err: Object): string {
    if (err instanceof Error) {
      return err.message;
    }
    return JSON.stringify(err);
  }
}
