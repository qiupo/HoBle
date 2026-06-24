import { Want } from '@kit.AbilityKit';
import { formBindingData, FormExtensionAbility, formInfo } from '@kit.FormKit';
import { GuardConfig } from '../model/GuardModels';
import { GuardCenter } from '../services/GuardCenter';
import { GuardWidgetStore } from '../services/GuardWidgetStore';

const BUNDLE_NAME: string = 'com.example.hoble';
const ENTRY_ABILITY_NAME: string = 'EntryAbility';
const ACTION_START_GUARD: string = 'start_guard';
const ACTION_STOP_GUARD: string = 'stop_guard';

export default class EntryFormAbility extends FormExtensionAbility {
  onAddForm(want: Want): formBindingData.FormBindingData {
    const formId: string = this.getFormId(want);
    const store: GuardWidgetStore = new GuardWidgetStore(this.context);
    if (formId.length > 0) {
      store.addForm(formId).then(() => {
        return store.updateForm(formId);
      }).catch(() => {
      });
    }
    return store.createBindingData(store.loadSync());
  }

  onUpdateForm(formId: string): void {
    const store: GuardWidgetStore = new GuardWidgetStore(this.context);
    store.updateForm(formId).catch(() => {
    });
  }

  onRemoveForm(formId: string): void {
    const store: GuardWidgetStore = new GuardWidgetStore(this.context);
    store.removeForm(formId).catch(() => {
    });
  }

  onFormEvent(formId: string, message: string): void {
    const action: string = this.parseAction(message);
    if (action === ACTION_START_GUARD || action === ACTION_STOP_GUARD) {
      this.handleGuardAction(formId, action);
      return;
    }
    this.refreshForm(formId);
  }

  onAcquireFormState(want: Want): formInfo.FormState {
    return formInfo.FormState.READY;
  }

  private handleGuardAction(formId: string, action: string): void {
    const config: GuardConfig = new GuardConfig(this.context, BUNDLE_NAME, ENTRY_ABILITY_NAME);
    const guardCenter: GuardCenter = new GuardCenter(config);
    guardCenter.initialize(false).then(() => {
      if (action === ACTION_STOP_GUARD) {
        return guardCenter.stopGuard();
      }
      return guardCenter.startGuard();
    }).then(() => {
      this.refreshForm(formId);
    }).catch((err: Object) => {
      this.refreshForm(formId);
      console.error(`HoBle widget guard action failed: ${this.formatError(err)}`);
    });
  }

  private refreshForm(formId: string): void {
    const store: GuardWidgetStore = new GuardWidgetStore(this.context);
    store.updateForm(formId).catch(() => {
    });
  }

  private getFormId(want: Want): string {
    if (want.parameters === undefined) {
      return '';
    }
    const formId: Object | undefined = want.parameters[formInfo.FormParam.IDENTITY_KEY];
    if (typeof formId === 'string') {
      return formId;
    }
    return '';
  }

  private parseAction(message: string): string {
    try {
      const params: Record<string, Object> = JSON.parse(message) as Record<string, Object>;
      const action: Object | undefined = params['action'];
      if (typeof action === 'string') {
        return action;
      }
    } catch (err) {
    }
    if (message.indexOf(ACTION_STOP_GUARD) >= 0) {
      return ACTION_STOP_GUARD;
    }
    if (message.indexOf(ACTION_START_GUARD) >= 0) {
      return ACTION_START_GUARD;
    }
    return '';
  }

  private formatError(err: Object): string {
    if (err instanceof Error) {
      return err.message;
    }
    return JSON.stringify(err);
  }
}
