import {
  FlutterPlugin,
  FlutterPluginBinding,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult,
} from '@ohos/flutter_ohos';
import { AvPlayManager } from './AvPlayManager';
import { AvRecordManager } from './AvRecordManager';

/** FlutterPluginRecordPlugin **/
export default class FlutterPluginRecordPlugin implements FlutterPlugin, MethodCallHandler {
  private channel: MethodChannel | undefined = undefined;
  private recordMp3: boolean = false;
  private isRecording: boolean = false;
  private record: AvRecordManager | undefined = undefined
  private player: AvPlayManager | undefined = undefined
  private filePath: string | undefined = undefined

  constructor() {
  }

  getUniqueClassName(): string {
    return "FlutterPluginRecordPlugin"
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), "flutter_plugin_record");
    this.channel.setMethodCallHandler(this)
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    if (this.channel != null) {
      this.channel.setMethodCallHandler(null)
    }
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    switch (call.method) {
      case 'init':
        this.init();
        break;
      case 'initRecordMp3':

        break;
      case 'start':
        this.start(call.argument('id'));
        break;
      case 'stop':
        this.stop();
        break;
      case 'play':
        this.play()
        break;
      case 'pause':
        this.pause()
        break;
      case 'playByPath':
        this.playByPath(call.argument('path'))
        break;
      case 'stopPlay':
        this.stopPlay();
        break;
      default:
        result.notImplemented()
        break;
    }
  }

  private init() {
    this.recordMp3 = false;
  }

  private initRecordMp3() {
    this.recordMp3 = true;
  }

  private start(id: string){
    if (this.isRecording) {
      return ;
    }
    if (!this.channel) {
      return;
    }
    this.record = new AvRecordManager(this.channel, id);
    const context: Context = getContext(this);
    let filePath: string = context.filesDir + '/example.mp3';
    this.record.startRecord(filePath)
  }

  private play(){
    if (!this.channel) {
      return;
    }
    if (this.filePath) {
      this.player?.startPlay(this.filePath);
    }
  }

  private playByPath(path: string){
    if (!this.channel) {
      return;
    }
    this.player?.startPlay(path);
  }

  private pause(){
    if (!this.channel) {
      return;
    }
    this.player?.pause();
  }

  private stopPlay(){
    if (!this.channel) {
      return;
    }
    this.player?.stop();
  }

  private stop(){
    if (!this.channel) {
      return;
    }
    this.record?.stopRecord();
  }
}