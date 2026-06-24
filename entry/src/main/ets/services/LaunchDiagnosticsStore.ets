import { AbilityConstant } from '@kit.AbilityKit';

let lastLaunchParam: AbilityConstant.LaunchParam | null = null;

export function setLastLaunchParam(launchParam: AbilityConstant.LaunchParam): void {
  lastLaunchParam = launchParam;
}

export function getLastLaunchParam(): AbilityConstant.LaunchParam | null {
  return lastLaunchParam;
}
