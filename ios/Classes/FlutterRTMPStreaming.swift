import Flutter
import UIKit
import AVFoundation
import Accelerate
import CoreMotion
import HaishinKit
import os
import ReplayKit
import VideoToolbox

@objc
public class FlutterRTMPStreaming : NSObject {
    private var rtmpConnection = RTMPConnection()
    private var rtmpStream: RTMPStream!
    private var url: String? = nil
    private var name: String? = nil
    private var retries: Int = 0
    private let eventSink: FlutterEventSink
    private let myDelegate = MyRTMPStreamQoSDelagate()
    
    @objc
    public init(sink: @escaping FlutterEventSink) {
        eventSink = sink
    }
    
    @objc
    public func open(url: String, width: Int, height: Int, bitrate: Int) {
        // Creamos la instancia principal RTMPStream
        rtmpStream = RTMPStream(connection: rtmpConnection)
        
        // =========================
        // ADDED/EDITED: Ajustes para mayor calidad
        // =========================
        // - .hd1920x1080 en vez de hd1280x720
        // - Si deseas 720p, déjalo como .hd1280x720 (pero verás menos nitidez)
        // - También agregamos continuousAutofocus, continuousExposure

        rtmpStream.captureSettings = [
            .sessionPreset: AVCaptureSession.Preset.hd1920x1080,  // o .hd1280x720
            .fps: 30,
            .continuousAutofocus: true,
            .continuousExposure: true
        ]

        // Escuchamos eventos RTMP
        rtmpConnection.addEventListener(.rtmpStatus, selector:#selector(rtmpStatusHandler), observer: self)
        rtmpConnection.addEventListener(.ioError, selector: #selector(rtmpErrorHandler), observer: self)
        
        let uri = URL(string: url)
        self.name = uri?.pathComponents.last
        var bits = url.components(separatedBy: "/")
        bits.removeLast()
        self.url = bits.joined(separator: "/")
        
        // Ajusta la config de video en HaishinKit:
        // - width/height: 1920x1080 (si deseas Full HD) o lo que recibas en params
        // - .bitrate: ~3500 kbps (3500 * 1024)
        // - .profileLevel: high en vez de baseline

        rtmpStream.videoSettings = [
            .width: width,    // 1920
            .height: height,  // 1080
            .profileLevel: kVTProfileLevel_H264_High_AutoLevel, // High en vez de Baseline
            .maxKeyFrameIntervalDuration: 2,
            .bitrate: bitrate // ej. 3500 * 1024
        ]
        // (fps lo definimos en captureSettings)

        // Delegado para cambio dinámico de bitrate si la red es insuficiente
        rtmpStream.delegate = myDelegate
        
        self.retries = 0
        
        // En la UI thread, ajustamos la orientación si es horizontal/vertical
        DispatchQueue.main.async {
            if let orientation = DeviceUtil.videoOrientation(by: UIApplication.shared.statusBarOrientation) {
                self.rtmpStream.orientation = orientation
                print(String(format: "Orient %d", orientation.rawValue))
                
                // Si detectas landscape, reasigna ancho/alto si gustas:
                switch orientation {
                case .landscapeLeft, .landscapeRight:
                    // Podrías forzar (width>height)
                    self.rtmpStream.videoSettings[.width] = width
                    self.rtmpStream.videoSettings[.height] = height
                default:
                    break
                }
            }
            // Conectamos
            self.rtmpConnection.connect(self.url ?? "frog")
        }
    }
    
    @objc
    private func rtmpStatusHandler(_ notification: Notification) {
        let e = Event.from(notification)
        guard let data: ASObject = e.data as? ASObject,
              let code: String = data["code"] as? String else {
            return
        }
        print(e)
        
        switch code {
        case RTMPConnection.Code.connectSuccess.rawValue:
            rtmpStream.publish(name)
            retries = 0
            break
        case RTMPConnection.Code.connectFailed.rawValue, RTMPConnection.Code.connectClosed.rawValue:
            guard retries <= 3 else {
                eventSink([
                    "event" : "error",
                    "errorDescription" : "connection failed " + e.type.rawValue
                ])
                return
            }
            retries += 1
            Thread.sleep(forTimeInterval: pow(2.0, Double(retries)))
            rtmpConnection.connect(url!)
            eventSink([
                "event" : "rtmp_retry",
                "errorDescription" : "connection failed " + e.type.rawValue
            ])
            break
        default:
            break
        }
    }
    
    @objc
    private func rtmpErrorHandler(_ notification: Notification) {
        if #available(iOS 10.0, *) {
            os_log("%s", notification.name.rawValue)
        }
        guard retries <= 3 else {
            eventSink([
                "event" : "rtmp_stopped",
                "errorDescription" : "rtmp disconnected"
            ])
            return
        }
        retries+=1
        Thread.sleep(forTimeInterval: pow(2.0, Double(retries)))
        rtmpConnection.connect(url!)
        eventSink([
            "event" : "rtmp_retry",
            "errorDescription" : "rtmp disconnected"
        ])
    }
    
    @objc
    public func pauseVideoStreaming() {
        rtmpStream.paused = true
    }
    
    @objc
    public func resumeVideoStreaming() {
        rtmpStream.paused = false
    }
    
    @objc
    public func isPaused() -> Bool {
        return rtmpStream.paused
    }
    
    @objc
    public func getStreamStatistics() -> NSDictionary {
        let ret: NSDictionary = [
            "paused": isPaused(),
            "bitrate": rtmpStream.videoSettings[.bitrate] ?? 0,
            "width": rtmpStream.videoSettings[.width] ?? 0,
            "height": rtmpStream.videoSettings[.height] ?? 0,
            "fps": rtmpStream.captureSettings[.fps] ?? 0,
            "orientation": rtmpStream.orientation.rawValue
        ]
        return ret
    }
    
    @objc
    public func addVideoData(buffer: CMSampleBuffer) {
        // Muestras de video (cuando usas el pipeline de FLTCam):
        if let description = CMSampleBufferGetFormatDescription(buffer) {
            let dimensions = CMVideoFormatDescriptionGetDimensions(description)
            rtmpStream.videoSettings = [
                .width: dimensions.width,
                .height: dimensions.height,
                .profileLevel: kVTProfileLevel_H264_High_AutoLevel, // High
                .maxKeyFrameIntervalDuration: 2,
                .bitrate: 1200 * 1024
            ]
            rtmpStream.captureSettings = [
                .fps: 24
            ]
        }
        rtmpStream.appendSampleBuffer(buffer, withType: .video)
    }
    
    @objc
    public func addAudioData(buffer: CMSampleBuffer) {
        rtmpStream.appendSampleBuffer(buffer, withType: .audio)
    }
    
    @objc
    public func close() {
        rtmpConnection.close()
    }
}


// QoS para ajustar bitrate dinámicamente según la red
class MyRTMPStreamQoSDelagate: RTMPStreamDelegate {
    let minBitrate: UInt32 = 300 * 1024
    let maxBitrate: UInt32 = 3500 * 1024 // ADDED/EDITED: sube el tope a 3.5 Mbps
    let incrementBitrate: UInt32 = 512 * 1024
    
    func didPublishSufficientBW(_ stream: RTMPStream, withConnection: RTMPConnection) {
        guard let videoBitrate = stream.videoSettings[.bitrate] as? UInt32 else { return }
        
        var newVideoBitrate = videoBitrate + incrementBitrate
        if newVideoBitrate > maxBitrate {
            newVideoBitrate = maxBitrate
        }
        print("didPublishSufficientBW update: \(videoBitrate) -> \(newVideoBitrate)")
        stream.videoSettings[.bitrate] = newVideoBitrate
    }
    
    func didPublishInsufficientBW(_ stream: RTMPStream, withConnection: RTMPConnection) {
        guard let videoBitrate = stream.videoSettings[.bitrate] as? UInt32 else { return }
        
        var newVideoBitrate = UInt32(videoBitrate / 2)
        if newVideoBitrate < minBitrate {
            newVideoBitrate = minBitrate
        }
        print("didPublishInsufficientBW update: \(videoBitrate) -> \(newVideoBitrate)")
        stream.videoSettings[.bitrate] = newVideoBitrate
    }
    
    func clear() {}
}





/*


import Flutter
import UIKit
import AVFoundation
import Accelerate
import CoreMotion
import HaishinKit
import os
import ReplayKit
import VideoToolbox

@objc
public class FlutterRTMPStreaming : NSObject {
    private var rtmpConnection = RTMPConnection()
    private var rtmpStream: RTMPStream!
    private var url: String? = nil
    private var name: String? = nil
    private var retries: Int = 0
    private let eventSink: FlutterEventSink
    private let myDelegate = MyRTMPStreamQoSDelagate()
    
    @objc
    public init(sink: @escaping FlutterEventSink) {
        eventSink = sink
    }
    
    @objc
    public func open(url: String, width: Int, height: Int, bitrate: Int) {
        // Creamos la instancia principal RTMPStream
        rtmpStream = RTMPStream(connection: rtmpConnection)
        
        // =========================
        // ADDED/EDITED: Ajustes para mayor calidad
        // =========================
        // - .hd1920x1080 en vez de hd1280x720
        // - Si deseas 720p, déjalo como .hd1280x720 (pero verás menos nitidez)
        // - También agregamos continuousAutofocus, continuousExposure

        rtmpStream.captureSettings = [
            .sessionPreset: AVCaptureSession.Preset.hd1920x1080,  // o .hd1280x720
            .fps: 30,
            .continuousAutofocus: true,
            .continuousExposure: true
        ]

        // Escuchamos eventos RTMP
        rtmpConnection.addEventListener(.rtmpStatus, selector:#selector(rtmpStatusHandler), observer: self)
        rtmpConnection.addEventListener(.ioError, selector: #selector(rtmpErrorHandler), observer: self)
        
        let uri = URL(string: url)
        self.name = uri?.pathComponents.last
        var bits = url.components(separatedBy: "/")
        bits.removeLast()
        self.url = bits.joined(separator: "/")
        
        // Ajusta la config de video en HaishinKit:
        // - width/height: 1920x1080 (si deseas Full HD) o lo que recibas en params
        // - .bitrate: ~3500 kbps (3500 * 1024)
        // - .profileLevel: high en vez de baseline

        rtmpStream.videoSettings = [
            .width: width,    // 1920
            .height: height,  // 1080
            .profileLevel: kVTProfileLevel_H264_High_AutoLevel, // High en vez de Baseline
            .maxKeyFrameIntervalDuration: 2,
            .bitrate: bitrate // ej. 3500 * 1024
        ]
        // (fps lo definimos en captureSettings)

        // Delegado para cambio dinámico de bitrate si la red es insuficiente
        rtmpStream.delegate = myDelegate
        
        self.retries = 0
        
        // En la UI thread, ajustamos la orientación si es horizontal/vertical
        DispatchQueue.main.async {
            if let orientation = DeviceUtil.videoOrientation(by: UIApplication.shared.statusBarOrientation) {
                self.rtmpStream.orientation = orientation
                print(String(format: "Orient %d", orientation.rawValue))
                
                // Si detectas landscape, reasigna ancho/alto si gustas:
                switch orientation {
                case .landscapeLeft, .landscapeRight:
                    // Podrías forzar (width>height)
                    self.rtmpStream.videoSettings[.width] = width
                    self.rtmpStream.videoSettings[.height] = height
                default:
                    break
                }
            }
            // Conectamos
            self.rtmpConnection.connect(self.url ?? "frog")
        }
    }
    
    @objc
    private func rtmpStatusHandler(_ notification: Notification) {
        let e = Event.from(notification)
        guard let data: ASObject = e.data as? ASObject,
              let code: String = data["code"] as? String else {
            return
        }
        print(e)
        
        switch code {
        case RTMPConnection.Code.connectSuccess.rawValue:
            rtmpStream.publish(name)
            retries = 0
            break
        case RTMPConnection.Code.connectFailed.rawValue, RTMPConnection.Code.connectClosed.rawValue:
            guard retries <= 3 else {
                eventSink([
                    "event" : "error",
                    "errorDescription" : "connection failed " + e.type.rawValue
                ])
                return
            }
            retries += 1
            Thread.sleep(forTimeInterval: pow(2.0, Double(retries)))
            rtmpConnection.connect(url!)
            eventSink([
                "event" : "rtmp_retry",
                "errorDescription" : "connection failed " + e.type.rawValue
            ])
            break
        default:
            break
        }
    }
    
    @objc
    private func rtmpErrorHandler(_ notification: Notification) {
        if #available(iOS 10.0, *) {
            os_log("%s", notification.name.rawValue)
        }
        guard retries <= 3 else {
            eventSink([
                "event" : "rtmp_stopped",
                "errorDescription" : "rtmp disconnected"
            ])
            return
        }
        retries+=1
        Thread.sleep(forTimeInterval: pow(2.0, Double(retries)))
        rtmpConnection.connect(url!)
        eventSink([
            "event" : "rtmp_retry",
            "errorDescription" : "rtmp disconnected"
        ])
    }
    
    @objc
    public func pauseVideoStreaming() {
        rtmpStream.paused = true
    }
    
    @objc
    public func resumeVideoStreaming() {
        rtmpStream.paused = false
    }
    
    @objc
    public func isPaused() -> Bool {
        return rtmpStream.paused
    }
    
    @objc
    public func getStreamStatistics() -> NSDictionary {
        let ret: NSDictionary = [
            "paused": isPaused(),
            "bitrate": rtmpStream.videoSettings[.bitrate] ?? 0,
            "width": rtmpStream.videoSettings[.width] ?? 0,
            "height": rtmpStream.videoSettings[.height] ?? 0,
            "fps": rtmpStream.captureSettings[.fps] ?? 0,
            "orientation": rtmpStream.orientation.rawValue
        ]
        return ret
    }
    
    @objc
    public func addVideoData(buffer: CMSampleBuffer) {
        // Muestras de video (cuando usas el pipeline de FLTCam):
        if let description = CMSampleBufferGetFormatDescription(buffer) {
            let dimensions = CMVideoFormatDescriptionGetDimensions(description)
            rtmpStream.videoSettings = [
                .width: dimensions.width,
                .height: dimensions.height,
                .profileLevel: kVTProfileLevel_H264_High_AutoLevel, // High
                .maxKeyFrameIntervalDuration: 2,
                .bitrate: 1200 * 1024
            ]
            rtmpStream.captureSettings = [
                .fps: 24
            ]
        }
        rtmpStream.appendSampleBuffer(buffer, withType: .video)
    }
    
    @objc
    public func addAudioData(buffer: CMSampleBuffer) {
        rtmpStream.appendSampleBuffer(buffer, withType: .audio)
    }
    
    @objc
    public func close() {
        rtmpConnection.close()
    }
}


// QoS para ajustar bitrate dinámicamente según la red
class MyRTMPStreamQoSDelagate: RTMPStreamDelegate {
    let minBitrate: UInt32 = 300 * 1024
    let maxBitrate: UInt32 = 3500 * 1024 // ADDED/EDITED: sube el tope a 3.5 Mbps
    let incrementBitrate: UInt32 = 512 * 1024
    
    func didPublishSufficientBW(_ stream: RTMPStream, withConnection: RTMPConnection) {
        guard let videoBitrate = stream.videoSettings[.bitrate] as? UInt32 else { return }
        
        var newVideoBitrate = videoBitrate + incrementBitrate
        if newVideoBitrate > maxBitrate {
            newVideoBitrate = maxBitrate
        }
        print("didPublishSufficientBW update: \(videoBitrate) -> \(newVideoBitrate)")
        stream.videoSettings[.bitrate] = newVideoBitrate
    }
    
    func didPublishInsufficientBW(_ stream: RTMPStream, withConnection: RTMPConnection) {
        guard let videoBitrate = stream.videoSettings[.bitrate] as? UInt32 else { return }
        
        var newVideoBitrate = UInt32(videoBitrate / 2)
        if newVideoBitrate < minBitrate {
            newVideoBitrate = minBitrate
        }
        print("didPublishInsufficientBW update: \(videoBitrate) -> \(newVideoBitrate)")
        stream.videoSettings[.bitrate] = newVideoBitrate
    }
    
    func clear() {}
}



*/
