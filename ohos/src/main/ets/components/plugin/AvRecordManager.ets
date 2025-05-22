import { media } from "@kit.MediaKit";
import { BusinessError } from "@kit.BasicServicesKit";
import { fileIo as fs } from '@kit.CoreFileKit';
import { MethodChannel } from "@ohos/flutter_ohos";

const TAG: string = 'AudioRecordManager';

export class AvRecordManager {
  private recorder: media.AVRecorder | undefined = undefined;
  private channel: MethodChannel | undefined = undefined;
  private id: string;
  private file: fs.File | undefined = undefined;
  private audioTimeLength: string | undefined = '0'
  private avProfile: media.AVRecorderProfile = {
    audioBitrate: 100000, // 音频比特率。
    audioChannels: 2, // 音频声道数。
    audioCodec: media.CodecMimeType.AUDIO_AAC, // 音频编码格式，当前支持ACC，MP3，G711MU。
    audioSampleRate: 48000, // 音频采样率。
    fileFormat: media.ContainerFormatType.CFT_MPEG_4A, // 封装格式，当前支持MP4，M4A，MP3，WAV。
  };
  private avConfig: media.AVRecorderConfig = {
    audioSourceType: media.AudioSourceType.AUDIO_SOURCE_TYPE_MIC, // 音频输入源，这里设置为麦克风。
    profile: this.avProfile,
    url: 'fd://35', // 参考应用文件访问与管理开发示例新建并读写一个文件。
  };

  private filePath: string | undefined = undefined;

  constructor(channel: MethodChannel,id: string) {
    this.channel = channel;
    this.id = id;
  }

  // 初始化音频采集器
  private async initAudioCapturer(): Promise<void> {

    media.createAVRecorder((err: BusinessError, recorder: media.AVRecorder) =>{
      if (recorder != null) {
        this.recorder = recorder
      }
    });
  }

  setAudioRecorderCallback() {
    if (this.recorder != undefined) {
      // 状态机变化回调函数。
      this.recorder.on('stateChange', (state: media.AVRecorderState, reason: media.StateChangeReason) => {
        console.log(`AudioRecorder current state is ${state}`);
        if (state == 'started') {
          let m1: Record<string, string> = {
            "id": this.id,
            'result': 'success'
          }
          this.channel?.invokeMethod('onStart', m1);
        } else if (state == 'stopped') {

        }
      })
      // 错误上报回调函数。
      this.recorder.on('error', (err: BusinessError) => {
        console.error(`AudioRecorder failed, code is ${err.code}, message is ${err.message}`);
      })
    }
  }

  // 开始录音
  public async startRecord(filePath: string): Promise<void> {
    if (this.recorder != undefined) {
      await this.recorder.release();
      this.recorder = undefined;
    }
    // 1.创建录制实例。
    this.recorder = await media.createAVRecorder();
    this.setAudioRecorderCallback();
    this.filePath = filePath;
    // 2.获取录制文件fd赋予avConfig里的url；参考FilePicker文档。
    this.file = fs.openSync(filePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE)
    this.avConfig.url = `fd://${this.file.fd}`
    // 3.配置录制参数完成准备工作。
    await this.recorder.prepare(this.avConfig);
    // 4.开始录制。
    await this.recorder.start();
  }

  // 停止录音
  public async stopRecord(): Promise<string | undefined> {
    if (this.recorder != undefined) {
      // 1. 停止录制。
      if (this.recorder.state === 'started'
        || this.recorder.state === 'paused') { // 仅在started或者paused状态下调用stop为合理状态切换。
        await this.recorder.stop();
      }
      let avMetadataExtractor = await media.createAVMetadataExtractor()
      avMetadataExtractor.fdSrc = fs.openSync(this.filePath);
      let metadata = await avMetadataExtractor.fetchMetadata();
      this.audioTimeLength = metadata.duration
      // 2.重置。
      await this.recorder.reset();
      // 3.释放录制实例。
      await this.recorder.release();
      this.recorder = undefined;
      // 4.关闭录制文件fd。
      fs.close(this.file);
      if (this.filePath != null && this.audioTimeLength) {
        let m1: Record<string, string> = {
          "id": this.id,
          'result': 'success',
          'voicePath' : this.filePath,
          'audioTimeLength': `${Number(this.audioTimeLength)/1000}`
        }
        this.channel?.invokeMethod('onStop', m1);
        return this.filePath;
      }
      return undefined;
    }
    return undefined;
  }

  public async release() {
      await this.recorder?.release();
      this.recorder = undefined;
  }

}