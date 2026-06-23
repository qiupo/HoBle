import { abilityAccessCtrl, common, PermissionRequestResult, Permissions } from '@kit.AbilityKit';

const USER_PERMISSIONS: Array<Permissions> = [
  'ohos.permission.ACCESS_BLUETOOTH'
];

export class PermissionService {
  private context: common.UIAbilityContext;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  async request(): Promise<boolean> {
    const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
    const result: PermissionRequestResult = await atManager.requestPermissionsFromUser(this.context, USER_PERMISSIONS);
    for (let index: number = 0; index < result.authResults.length; index++) {
      if (result.authResults[index] !== 0) {
        return false;
      }
    }
    return true;
  }

  hasAll(): boolean {
    try {
      const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
      const tokenId: number = this.context.applicationInfo.accessTokenId;
      for (let index: number = 0; index < USER_PERMISSIONS.length; index++) {
        if (atManager.checkAccessTokenSync(tokenId, USER_PERMISSIONS[index]) !== abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
          return false;
        }
      }
      return true;
    } catch (err) {
      return false;
    }
  }
}
