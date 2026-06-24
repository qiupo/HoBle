type WidgetActionHandler = (action: string) => void;

let widgetActionHandler: WidgetActionHandler | null = null;
let pendingAction: string = '';

export function setWidgetActionHandler(handler: WidgetActionHandler | null): void {
  widgetActionHandler = handler;
  flushPendingAction();
}

export function requestWidgetAction(action: string): void {
  if (action.length === 0) {
    return;
  }
  pendingAction = action;
  flushPendingAction();
}

function flushPendingAction(): void {
  if (widgetActionHandler === null || pendingAction.length === 0) {
    return;
  }
  const action: string = pendingAction;
  pendingAction = '';
  widgetActionHandler(action);
}

export function isStartGuardAction(action: string): boolean {
  return action === 'start_guard';
}
