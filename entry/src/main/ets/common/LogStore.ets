import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0x0001;
const TAG: string = 'HoBleGuard';
const MAX_LOG_COUNT: number = 20;

export class LogStore {
  private logs: Array<string> = [];

  info(message: string): void {
    this.append('INFO', message);
  }

  warn(message: string): void {
    this.append('WARN', message);
  }

  error(message: string): void {
    this.append('ERROR', message);
  }

  getLogs(): Array<string> {
    return this.logs.slice();
  }

  private append(level: string, message: string): void {
    const item: string = `${this.formatTime()} ${level} ${message}`;
    this.logs.unshift(item);
    if (this.logs.length > MAX_LOG_COUNT) {
      this.logs.pop();
    }
    hilog.info(DOMAIN, TAG, '%{public}s', item);
  }

  private formatTime(): string {
    const now: Date = new Date();
    const hour: string = this.pad(now.getHours());
    const minute: string = this.pad(now.getMinutes());
    const second: string = this.pad(now.getSeconds());
    return `${hour}:${minute}:${second}`;
  }

  private pad(value: number): string {
    if (value < 10) {
      return `0${value}`;
    }
    return `${value}`;
  }
}
