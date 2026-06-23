import { common, wantAgent } from '@kit.AbilityKit';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';

export class BackgroundTaskService {
  private context: common.UIAbilityContext;
  private bundleName: string;
  private abilityName: string;
  private running: boolean = false;
  private continuousTaskId: number = 0;

  constructor(context: common.UIAbilityContext, bundleName: string, abilityName: string) {
    this.context = context;
    this.bundleName = bundleName;
    this.abilityName = abilityName;
  }

  async start(): Promise<void> {
    if (this.running) {
      return;
    }
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
    request.backgroundTaskModes = [backgroundTaskManager.BackgroundTaskMode.MODE_BLUETOOTH_INTERACTION];
    request.backgroundTaskSubmodes = [backgroundTaskManager.BackgroundTaskSubmode.SUBMODE_NORMAL_NOTIFICATION];
    request.wantAgent = agent;
    const notification = await backgroundTaskManager.startBackgroundRunning(this.context, request);
    this.continuousTaskId = notification.continuousTaskId ?? 0;
    this.running = true;
  }

  async stop(): Promise<void> {
    if (!this.running) {
      return;
    }
    await backgroundTaskManager.stopBackgroundRunning(this.context, this.continuousTaskId);
    this.running = false;
    this.continuousTaskId = 0;
  }

  isRunning(): boolean {
    return this.running;
  }

  async refresh(): Promise<boolean> {
    try {
      const tasks = await backgroundTaskManager.getAllContinuousTasks(this.context);
      this.running = tasks.length > 0;
      if (this.running) {
        for (let index: number = 0; index < tasks.length; index++) {
          if (tasks[index].continuousTaskId === this.continuousTaskId) {
            return true;
          }
        }
        this.continuousTaskId = tasks[0].continuousTaskId;
      } else {
        this.continuousTaskId = 0;
      }
    } catch (err) {
      this.running = this.continuousTaskId > 0;
    }
    return this.running;
  }
}
