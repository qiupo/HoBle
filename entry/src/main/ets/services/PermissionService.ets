import { abilityAccessCtrl, common, PermissionRequestResult, Permissions } from '@kit.AbilityKit';

const FOREGROUND_PERMISSIONS: Array<Permissions> = [
  'ohos.permission.ACCESS_BLUETOOTH',
  'ohos.permission.APPROXIMATELY_LOCATION'
];

const BACKGROUND_PERMISSIONS: Array<Permissions> = [
  'ohos.permission.LOCATION_IN_BACKGROUND'
];

const USER_PERMISSIONS: Array<Permissions> = [
  'ohos.permission.ACCESS_BLUETOOTH',
  'ohos.permission.APPROXIMATELY_LOCATION',
  'ohos.permission.LOCATION_IN_BACKGROUND'
];

export class PermissionService {
  private context: common.Context;

  constructor(context: common.Context) {
    this.context = context;
  }

  async request(): Promise<boolean> {
    if (this.hasAll()) {
      return true;
    }
    if (!this.hasPermissions(FOREGROUND_PERMISSIONS)) {
      await this.requestPermissionGroup(FOREGROUND_PERMISSIONS);
    }
    if (!this.hasPermissions(FOREGROUND_PERMISSIONS)) {
      return false;
    }
    if (!this.hasPermissions(BACKGROUND_PERMISSIONS)) {
      await this.requestPermissionGroup(BACKGROUND_PERMISSIONS);
    }
    return this.hasAll();
  }

  hasAll(): boolean {
    return this.hasPermissions(USER_PERMISSIONS);
  }

  getMissingPermissionText(): string {
    const missingPermissions: Array<Permissions> = this.getMissingPermissions();
    if (missingPermissions.length === 0) {
      return '无';
    }
    let result: string = '';
    for (let index: number = 0; index < missingPermissions.length; index++) {
      if (result.length > 0) {
        result += '、';
      }
      result += this.describePermission(missingPermissions[index]);
    }
    return result;
  }

  private getMissingPermissions(): Array<Permissions> {
    const result: Array<Permissions> = [];
    try {
      const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
      const tokenId: number = this.context.applicationInfo.accessTokenId;
      for (let index: number = 0; index < USER_PERMISSIONS.length; index++) {
        if (atManager.checkAccessTokenSync(tokenId, USER_PERMISSIONS[index]) !== abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
          result.push(USER_PERMISSIONS[index]);
        }
      }
    } catch (err) {
      for (let index: number = 0; index < USER_PERMISSIONS.length; index++) {
        result.push(USER_PERMISSIONS[index]);
      }
    }
    return result;
  }

  private hasPermissions(permissions: Array<Permissions>): boolean {
    try {
      const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
      const tokenId: number = this.context.applicationInfo.accessTokenId;
      for (let index: number = 0; index < permissions.length; index++) {
        if (atManager.checkAccessTokenSync(tokenId, permissions[index]) !== abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
          return false;
        }
      }
      return true;
    } catch (err) {
      return false;
    }
  }

  private async requestPermissionGroup(permissions: Array<Permissions>): Promise<boolean> {
    try {
      const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
      const result: PermissionRequestResult = await atManager.requestPermissionsFromUser(this.context as common.UIAbilityContext, permissions);
      for (let index: number = 0; index < result.authResults.length; index++) {
        if (result.authResults[index] !== 0) {
          return false;
        }
      }
      return true;
    } catch (err) {
      return false;
    }
  }

  private describePermission(permission: Permissions): string {
    if (permission === 'ohos.permission.ACCESS_BLUETOOTH') {
      return '蓝牙访问';
    }
    if (permission === 'ohos.permission.APPROXIMATELY_LOCATION') {
      return '大致位置';
    }
    if (permission === 'ohos.permission.LOCATION_IN_BACKGROUND') {
      return '后台位置';
    }
    return `${permission}`;
  }
}
