import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { GuardSettings } from '../model/GuardModels';

const STORE_NAME: string = 'guard_settings';
const KEY_ENABLED: string = 'enabled';
const KEY_DEVICE_ID: string = 'device_id';
const DEFAULT_DEVICE_ID: string = 'HoBle-Guard';

export class SettingsStore {
  private context: common.Context;

  constructor(context: common.Context) {
    this.context = context;
  }

  async load(): Promise<GuardSettings> {
    const store: preferences.Preferences = await preferences.getPreferences(this.context, STORE_NAME);
    const settings: GuardSettings = new GuardSettings();
    settings.enabled = await store.get(KEY_ENABLED, false) as boolean;
    settings.deviceId = await store.get(KEY_DEVICE_ID, DEFAULT_DEVICE_ID) as string;
    return settings;
  }

  loadSync(): GuardSettings {
    const settings: GuardSettings = new GuardSettings();
    settings.enabled = false;
    settings.deviceId = DEFAULT_DEVICE_ID;
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(this.context, { name: STORE_NAME });
      settings.enabled = store.getSync(KEY_ENABLED, false) as boolean;
      settings.deviceId = store.getSync(KEY_DEVICE_ID, DEFAULT_DEVICE_ID) as string;
    } catch (err) {
    }
    return settings;
  }

  async save(settings: GuardSettings): Promise<void> {
    const store: preferences.Preferences = await preferences.getPreferences(this.context, STORE_NAME);
    await store.put(KEY_ENABLED, settings.enabled);
    await store.put(KEY_DEVICE_ID, settings.deviceId);
    await store.flush();
  }
}
