import { common } from '@kit.AbilityKit';
import { formBindingData, formProvider } from '@kit.FormKit';
import { preferences } from '@kit.ArkData';
import { GuardRunState, GuardSettings, GuardSnapshot } from '../model/GuardModels';
import { SettingsStore } from './SettingsStore';

const STORE_NAME: string = 'guard_widget';
const KEY_ENABLED: string = 'enabled';
const KEY_RUN_STATE: string = 'run_state';
const KEY_BLE_STATE: string = 'ble_state';
const KEY_ADVERTISING_TEXT: string = 'advertising_text';
const KEY_BACKGROUND_TEXT: string = 'background_text';
const KEY_PERMISSION_TEXT: string = 'permission_text';
const KEY_LAST_MESSAGE: string = 'last_message';
const KEY_UPDATED_AT: string = 'updated_at';
const KEY_FORM_IDS: string = 'form_ids';

export class GuardWidgetData {
  enabledText: string = '等待同步';
  runState: string = GuardRunState.STOPPED;
  bleState: string = '待刷新';
  advertisingText: string = '待刷新';
  backgroundText: string = '待刷新';
  permissionText: string = '待刷新';
  buttonText: string = '开启守护';
  lastMessage: string = '点击按钮开启守护并刷新状态';
  updatedAt: string = '未同步';
  statusTone: string = 'idle';
}

export class GuardWidgetStore {
  private context: common.Context;

  constructor(context: common.Context) {
    this.context = context;
  }

  async load(): Promise<GuardWidgetData> {
    const data: GuardWidgetData = new GuardWidgetData();
    try {
      const store: preferences.Preferences = await preferences.getPreferences(this.context, STORE_NAME);
      const enabled: boolean = await store.get(KEY_ENABLED, false) as boolean;
      data.enabledText = enabled ? '守护已启用' : '守护未启用';
      data.runState = await store.get(KEY_RUN_STATE, GuardRunState.STOPPED) as string;
      data.bleState = await store.get(KEY_BLE_STATE, '待刷新') as string;
      data.advertisingText = await store.get(KEY_ADVERTISING_TEXT, '待刷新') as string;
      data.backgroundText = await store.get(KEY_BACKGROUND_TEXT, '待刷新') as string;
      data.permissionText = await store.get(KEY_PERMISSION_TEXT, '待刷新') as string;
      data.lastMessage = await store.get(KEY_LAST_MESSAGE, '点击按钮开启守护并刷新状态') as string;
      data.updatedAt = await store.get(KEY_UPDATED_AT, '未同步') as string;
      data.runState = this.deriveRunState(enabled, data);
      data.statusTone = this.buildStatusTone(enabled, data);
      data.buttonText = this.buildButtonText(data);
    } catch (err) {
      data.lastMessage = `组件状态读取失败：${this.formatError(err)}`;
    }
    return this.applySettingsFallback(data);
  }

  loadSync(): GuardWidgetData {
    const data: GuardWidgetData = new GuardWidgetData();
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(this.context, { name: STORE_NAME });
      const enabled: boolean = store.getSync(KEY_ENABLED, false) as boolean;
      data.enabledText = enabled ? '守护已启用' : '守护未启用';
      data.runState = store.getSync(KEY_RUN_STATE, GuardRunState.STOPPED) as string;
      data.bleState = store.getSync(KEY_BLE_STATE, '待刷新') as string;
      data.advertisingText = store.getSync(KEY_ADVERTISING_TEXT, '待刷新') as string;
      data.backgroundText = store.getSync(KEY_BACKGROUND_TEXT, '待刷新') as string;
      data.permissionText = store.getSync(KEY_PERMISSION_TEXT, '待刷新') as string;
      data.lastMessage = store.getSync(KEY_LAST_MESSAGE, '点击按钮开启守护并刷新状态') as string;
      data.updatedAt = store.getSync(KEY_UPDATED_AT, '未同步') as string;
      data.runState = this.deriveRunState(enabled, data);
      data.statusTone = this.buildStatusTone(enabled, data);
      data.buttonText = this.buildButtonText(data);
    } catch (err) {
      data.lastMessage = `组件状态读取失败：${this.formatError(err)}`;
    }
    return this.applySettingsFallback(data);
  }

  async saveSnapshot(snapshot: GuardSnapshot): Promise<void> {
    const enabled: boolean = snapshot.guardEnabled;
    const data: GuardWidgetData = this.fromSnapshot(snapshot, enabled);
    try {
      const store: preferences.Preferences = await preferences.getPreferences(this.context, STORE_NAME);
      await store.put(KEY_ENABLED, enabled);
      await store.put(KEY_RUN_STATE, data.runState);
      await store.put(KEY_BLE_STATE, data.bleState);
      await store.put(KEY_ADVERTISING_TEXT, data.advertisingText);
      await store.put(KEY_BACKGROUND_TEXT, data.backgroundText);
      await store.put(KEY_PERMISSION_TEXT, data.permissionText);
      await store.put(KEY_LAST_MESSAGE, data.lastMessage);
      await store.put(KEY_UPDATED_AT, data.updatedAt);
      await store.flush();
    } catch (err) {
      throw new Error(`保存桌面组件状态失败：${this.formatError(err)}`);
    }
    await this.updateRegisteredForms(data);
  }

  async addForm(formId: string): Promise<void> {
    if (formId.length === 0) {
      return;
    }
    const formIds: Array<string> = await this.loadFormIds();
    if (formIds.indexOf(formId) < 0) {
      formIds.push(formId);
      await this.saveFormIds(formIds);
    }
  }

  async removeForm(formId: string): Promise<void> {
    const formIds: Array<string> = await this.loadFormIds();
    const nextFormIds: Array<string> = [];
    for (let index: number = 0; index < formIds.length; index++) {
      if (formIds[index] !== formId) {
        nextFormIds.push(formIds[index]);
      }
    }
    await this.saveFormIds(nextFormIds);
  }

  async updateForm(formId: string): Promise<void> {
    const data: GuardWidgetData = await this.load();
    try {
      await formProvider.updateForm(formId, this.createBindingData(data));
    } catch (err) {
      throw new Error(`刷新桌面组件失败：${this.formatError(err)}`);
    }
  }

  createBindingData(data: GuardWidgetData): formBindingData.FormBindingData {
    return formBindingData.createFormBindingData(data);
  }

  private fromSnapshot(snapshot: GuardSnapshot, enabled: boolean): GuardWidgetData {
    const data: GuardWidgetData = new GuardWidgetData();
    data.enabledText = enabled ? '守护已启用' : '守护未启用';
    data.runState = snapshot.runState;
    data.bleState = snapshot.blePowerState;
    data.advertisingText = snapshot.advertising ? '广播中' : '未广播';
    data.backgroundText = snapshot.backgroundRunning ? '后台运行中' : '后台未运行';
    data.permissionText = snapshot.permissionGranted ? '权限已授权' : '缺少权限';
    data.lastMessage = snapshot.lastMessage;
    data.updatedAt = this.formatTime(new Date());
    data.runState = this.deriveRunState(enabled, data);
    data.statusTone = this.buildStatusTone(enabled, data);
    data.buttonText = this.buildButtonText(data);
    return data;
  }

  private async updateRegisteredForms(data: GuardWidgetData): Promise<void> {
    const formIds: Array<string> = await this.loadFormIds();
    const aliveFormIds: Array<string> = [];
    for (let index: number = 0; index < formIds.length; index++) {
      const formId: string = formIds[index];
      try {
        await formProvider.updateForm(formId, this.createBindingData(data));
        aliveFormIds.push(formId);
      } catch (err) {
        const message: string = this.formatError(err);
        if (message.indexOf('16501001') < 0) {
          aliveFormIds.push(formId);
        }
      }
    }
    if (aliveFormIds.length !== formIds.length) {
      await this.saveFormIds(aliveFormIds);
    }
  }

  private async loadFormIds(): Promise<Array<string>> {
    try {
      const store: preferences.Preferences = await preferences.getPreferences(this.context, STORE_NAME);
      const rawValue: string = await store.get(KEY_FORM_IDS, '') as string;
      if (rawValue.length === 0) {
        return [];
      }
      return rawValue.split(',');
    } catch (err) {
      return [];
    }
  }

  private async saveFormIds(formIds: Array<string>): Promise<void> {
    try {
      const store: preferences.Preferences = await preferences.getPreferences(this.context, STORE_NAME);
      await store.put(KEY_FORM_IDS, formIds.join(','));
      await store.flush();
    } catch (err) {
      throw new Error(`保存桌面组件 ID 失败：${this.formatError(err)}`);
    }
  }

  private buildStatusTone(enabled: boolean, data: GuardWidgetData): string {
    if (this.isRunning(data)) {
      return 'running';
    }
    if (data.runState === GuardRunState.STARTING || data.runState === GuardRunState.STOPPING) {
      return 'pending';
    }
    if (enabled) {
      return 'pending';
    }
    return 'idle';
  }

  private buildButtonText(data: GuardWidgetData): string {
    if (this.isRunning(data)) {
      return '守护运行中';
    }
    if (data.runState === GuardRunState.STARTING) {
      return '启动中';
    }
    if (data.runState === GuardRunState.STOPPING) {
      return '停止中';
    }
    return '开启守护';
  }

  private deriveRunState(enabled: boolean, data: GuardWidgetData): string {
    if (this.isRunning(data)) {
      return GuardRunState.RUNNING;
    }
    if (data.runState === GuardRunState.STARTING || data.runState === GuardRunState.STOPPING) {
      return data.runState;
    }
    if (enabled && (
      data.bleState === '蓝牙开启' ||
      data.advertisingText === '广播中' ||
      data.backgroundText === '后台运行中' ||
      data.permissionText === '权限已授权'
    )) {
      return GuardRunState.STARTING;
    }
    return GuardRunState.STOPPED;
  }

  private applySettingsFallback(data: GuardWidgetData): GuardWidgetData {
    if (data.updatedAt !== '未同步') {
      return data;
    }
    const settings: GuardSettings = new SettingsStore(this.context).loadSync();
    if (settings.enabled) {
      data.enabledText = '守护已启用';
      data.runState = GuardRunState.STOPPED;
      data.statusTone = 'pending';
      data.buttonText = '开启守护';
      data.lastMessage = '组件未拿到运行快照，点击开启守护刷新';
    } else if (data.enabledText === '等待同步') {
      data.enabledText = '守护未启用';
    }
    return data;
  }

  private formatTime(date: Date): string {
    const hours: string = this.pad(date.getHours());
    const minutes: string = this.pad(date.getMinutes());
    return `${hours}:${minutes}`;
  }

  private pad(value: number): string {
    if (value < 10) {
      return `0${value}`;
    }
    return `${value}`;
  }

  private formatError(err: Object): string {
    if (err instanceof Error) {
      return err.message;
    }
    return JSON.stringify(err);
  }

  private isRunning(data: GuardWidgetData): boolean {
    return data.bleState === '蓝牙开启' &&
      data.advertisingText === '广播中' &&
      data.backgroundText === '后台运行中';
  }
}
