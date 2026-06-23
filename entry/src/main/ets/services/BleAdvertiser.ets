import { access, ble } from '@kit.ConnectivityKit';

const MANUFACTURER_ID: number = 0x0B1E;

export class BleAdvertiser {
  private advertising: boolean = false;

  isBluetoothOn(): boolean {
    try {
      return access.getState() === access.BluetoothState.STATE_ON;
    } catch (err) {
      return false;
    }
  }

  isAdvertising(): boolean {
    return this.advertising;
  }

  async start(deviceId: string): Promise<void> {
    if (this.advertising) {
      return;
    }
    const params: ble.AdvertiseSetting = {
      interval: 160,
      txPower: 0,
      connectable: false
    };
    const data: ble.AdvertiseData = {
      serviceUuids: [],
      manufactureData: [{
        manufactureId: MANUFACTURER_ID,
        manufactureValue: this.toBytes(deviceId)
      }],
      serviceData: []
    };
    ble.startAdvertising(params, data);
    this.advertising = true;
  }

  async stop(): Promise<void> {
    if (!this.advertising) {
      return;
    }
    ble.stopAdvertising();
    this.advertising = false;
  }

  private toBytes(value: string): ArrayBuffer {
    const length: number = Math.min(value.length, 20);
    const bytes: Uint8Array = new Uint8Array(length);
    for (let index: number = 0; index < length; index++) {
      bytes[index] = value.charCodeAt(index) & 0xFF;
    }
    return bytes.buffer;
  }
}
