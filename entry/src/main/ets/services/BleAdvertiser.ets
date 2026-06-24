import { access, ble } from '@kit.ConnectivityKit';

const MANUFACTURER_ID: number = 0x0B1E;

export class BleAdvertiser {
  private advertising: boolean = false;
  private advertisingId: number = -1;
  private statusListener?: (advertising: boolean) => void;
  private advertisingStateChangeCallback = (info: ble.AdvertisingStateChangeInfo): void => {
    if (this.advertisingId >= 0 && info.advertisingId !== this.advertisingId) {
      return;
    }
    this.advertising = info.state === ble.AdvertisingState.STARTED || info.state === ble.AdvertisingState.ENABLED;
    this.statusListener?.(this.advertising);
  };

  constructor() {
    try {
      ble.on('advertisingStateChange', this.advertisingStateChangeCallback);
    } catch (err) {
      // The guard can still run on devices that do not support advertising callbacks.
    }
  }

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

  setStatusListener(listener: (advertising: boolean) => void): void {
    this.statusListener = listener;
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
    try {
      this.advertisingId = await ble.startAdvertising({
        advertisingSettings: params,
        advertisingData: data
      });
    } catch (err) {
      ble.startAdvertising(params, data);
      this.advertisingId = -1;
    }
    this.advertising = true;
    this.statusListener?.(true);
  }

  async stop(): Promise<void> {
    try {
      if (this.advertisingId >= 0) {
        await ble.stopAdvertising(this.advertisingId);
      } else {
        ble.stopAdvertising();
      }
    } catch (err) {
      if (this.advertisingId >= 0) {
        try {
          ble.stopAdvertising();
        } catch (fallbackErr) {
        }
      }
    }
    this.advertisingId = -1;
    this.advertising = false;
    this.statusListener?.(false);
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
