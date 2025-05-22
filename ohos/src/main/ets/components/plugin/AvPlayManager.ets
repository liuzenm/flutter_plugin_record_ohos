// audio_record_manager.ets
import { fileIo as fs } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { media } from '@kit.MediaKit';
import { audio } from '@kit.AudioKit';
import { Any, MethodChannel } from '@ohos/flutter_ohos';

const TAG: string = 'AudioRecordManager';

export class AvPlayManager {
  private avPlayer: media.AVPlayer | null = null;
  private file: fs.File | null = null;
  private channel: MethodChannel | undefined = undefined;
  private id: string;
  private isplaying: boolean = false;
  private tempFilePath: string = '';

  constructor(channel: MethodChannel, id: string) {
    this.channel = channel;
    this.id = id;
  }

  setAVPlayerCallback(avPlayer: media.AVPlayer) {
    // seek操作结果回调函数。
    avPlayer.on('seekDone', (seekDoneTime: number) => {
      console.info(`AVPlayer seek succeeded, seek time is ${seekDoneTime}`);
    });
    // error回调监听函数,当avPlayer在操作过程中出现错误时调用 reset接口触发重置流程。
    avPlayer.on('error', (err: BusinessError) => {
      console.error(`Invoke avPlayer failed, code is ${err.code}, message is ${err.message}`);
      avPlayer.reset(); // 调用reset重置资源，触发idle状态。
    });

    //
    avPlayer.on('amplitudeUpdate', (value: Array<number>) => {
      let m1: Record<string, Any> = {
        "id": this.id,
        "amplitude": value[0] / 100,
        "result": 'success'
      }
      this.channel?.invokeMethod('onAmplitude', m1);
    });
    // 状态机变化回调函数。
    avPlayer.on('stateChange', async (state: string, reason: media.StateChangeReason) => {
      let m2: Record<string, string> = {
        "id": this.id,
        'playPath': this.tempFilePath,
        'playState': state
      }
      this.channel?.invokeMethod('onPlayState', m2);
      switch (state) {
        case 'idle': // 成功调用reset接口后触发该状态机上报。
          console.info('AVPlayer state idle called.');
          avPlayer.release(); // 调用release接口销毁实例对象。
          break;
        case 'initialized': // avplayer 设置播放源后触发该状态上报。
          console.info('AVPlayer state initialized called.');
          avPlayer.audioRendererInfo = {
            usage: audio.StreamUsage.STREAM_USAGE_MUSIC, // 音频流使用类型：音乐。根据业务场景配置，参考StreamUsage。
            rendererFlags: 0 // 音频渲染器标志。
          };
          avPlayer.prepare();
          break;
        case 'prepared': // prepare调用成功后上报该状态机。
          console.info('AVPlayer state prepared called.');
          avPlayer.play();
          break;
        case 'playing': // play成功调用后触发该状态机上报。
          let m1: Record<string, string> = {
            "id": this.id
          }
          this.channel?.invokeMethod('onPlay', m1);
          break;
        case 'paused': // pause成功调用后触发该状态机上报。
          let m2: Record<string, string> = {
            "id": this.id,
            'result': 'success',
            'isPlaying': 'false'
          }
          this.channel?.invokeMethod('pausePlay', m2);
          break;
        case 'completed': // 播放结束后触发该状态机上报。
          console.info('AVPlayer state completed called.');
          avPlayer.stop(); //调用播放结束接口。
          break;
        case 'stopped': // stop接口成功调用后触发该状态机上报。
          break;
        case 'released':
          console.info('AVPlayer state released called.');
          break;
        default:
          console.info('AVPlayer state unknown called.');
          break;
      }
    });
  }


  // 开始录音
  public async startPlay(filePath: string): Promise<void> {
    if (this.isplaying) {
      console.error(TAG, 'Recording is already in progress');
      return;
    }
    try {
      this.avPlayer = await media.createAVPlayer();
      this.setAVPlayerCallback(this.avPlayer);
      this.tempFilePath = filePath;
      // 创建并打开文件流
      this.file = await fs.open(this.tempFilePath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE);
      this.avPlayer.url = 'fd://' + this.file.fd;
    } catch (error) {
      console.error(TAG, 'Start play failed: ' + error.message);
    }
  }

  public async pause(): Promise<void> {

    try {
      this.avPlayer?.pause();

    } catch (error) {
      console.error(TAG, 'pause failed: ' + error.message);
    }
  }

  // 停止录音
  public async stop() {

    try {
      await this.avPlayer?.stop();
      await this.avPlayer?.release();
      this.avPlayer = null;
      await fs.close(this.file?.fd);
    } catch (error) {
      console.error(TAG, 'Stop play failed: ' + error.message);
    }
  }

  // 停止录音
  public async release() {
    try {
      await this.avPlayer?.release();
      this.avPlayer = null;
    } catch (error) {
      console.error(TAG, 'Stop play failed: ' + error.message);
    }
  }
}