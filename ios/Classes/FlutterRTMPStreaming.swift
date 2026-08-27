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

    private func parseRtmpEndpoint(_ rawUrl: String) -> (connectUrl: String, streamName: String)? {
        guard let components: URLComponents = URLComponents(string: rawUrl),
              let scheme: String = components.scheme,
              let host: String = components.host else {
            return nil
        }

        let pathSegments: [String] = components.percentEncodedPath
            .split(separator: "/")
            .map(String.init)
        guard let streamPathSegment: String = pathSegments.last, !streamPathSegment.isEmpty else {
            return nil
        }

        let appPathSegments: ArraySlice<String> = pathSegments.dropLast()
        let appPath: String = appPathSegments.isEmpty ? "/" : "/" + appPathSegments.joined(separator: "/")

        var connectComponents: URLComponents = URLComponents()
        connectComponents.scheme = scheme
        connectComponents.host = host
        connectComponents.port = components.port
        connectComponents.user = components.user
        connectComponents.password = components.password
        connectComponents.percentEncodedPath = appPath

        guard let connectUrl: String = connectComponents.string else {
            return nil
        }

        var streamName: String = streamPathSegment
        if let query: String = components.percentEncodedQuery, !query.isEmpty {
            streamName += "?\(query)"
        }
        return (connectUrl, streamName)
    }

    private func currentInterfaceOrientation() -> UIInterfaceOrientation? {
        if #available(iOS 13.0, *) {
            let scenes: Set<UIScene> = UIApplication.shared.connectedScenes
            let foregroundScene: UIWindowScene? = scenes
                .compactMap { $0 as? UIWindowScene }
                .first(where: { $0.activationState == .foregroundActive })
            let anyWindowScene: UIWindowScene? = scenes
                .compactMap { $0 as? UIWindowScene }
                .first
            return (foregroundScene ?? anyWindowScene)?.interfaceOrientation
        }
        return UIApplication.shared.statusBarOrientation
    }

    private func scheduleReconnect(errorDescription: String, terminalEvent: String) {
        guard retries <= 3 else {
            eventSink([
                "event": terminalEvent,
                "errorDescription": errorDescription
            ])
            return
        }

        retries += 1
        let reconnectDelay: Double = pow(2.0, Double(retries))
        guard let reconnectUrl: String = url else {
            eventSink([
                "event": "error",
                "errorDescription": "rtmp reconnect URL is missing"
            ])
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + reconnectDelay) { [weak self] in
            guard let self = self else {
                return
            }
            self.rtmpConnection.connect(reconnectUrl)
            self.eventSink([
                "event": "rtmp_retry",
                "errorDescription": errorDescription
            ])
        }
    }
    
    @objc
    public func open(url: String, width: Int, height: Int, bitrate: Int) {
        rtmpStream = RTMPStream(connection: rtmpConnection)
        rtmpStream.sessionPreset = AVCaptureSession.Preset.hd1280x720
        rtmpStream.frameRate = 30
        rtmpConnection.addEventListener(.rtmpStatus, selector:#selector(rtmpStatusHandler), observer: self)
        rtmpConnection.addEventListener(.ioError, selector: #selector(rtmpErrorHandler), observer: self)
        
        guard let endpoint: (connectUrl: String, streamName: String) = parseRtmpEndpoint(url) else {
            eventSink([
                "event": "error",
                "errorDescription": "invalid RTMP URL"
            ])
            return
        }
        self.url = endpoint.connectUrl
        self.name = endpoint.streamName
        
        // TODO: Da correggere
        var videoSettings: VideoCodecSettings = rtmpStream.videoSettings
        videoSettings.videoSize = CGSize(width: width, height: height)
        videoSettings.profileLevel = kVTProfileLevel_H264_Baseline_AutoLevel as String
        videoSettings.maxKeyFrameIntervalDuration = 2
        videoSettings.bitRate = bitrate
        rtmpStream.videoSettings = videoSettings
        rtmpConnection.delegate = myDelegate
        self.retries = 0
        // Run this on the ui thread.
        DispatchQueue.main.async {
            if let interfaceOrientation: UIInterfaceOrientation = self.currentInterfaceOrientation(),
               let orientation = DeviceUtil.videoOrientation(by: interfaceOrientation) {
                self.rtmpStream.videoOrientation = orientation
                print(String(format:"Orient %d", orientation.rawValue))
                switch (orientation) {
                case .landscapeLeft, .landscapeRight:
                    var updatedVideoSettings: VideoCodecSettings = self.rtmpStream.videoSettings
                    updatedVideoSettings.videoSize = CGSize(width: width, height: height)
                    self.rtmpStream.videoSettings = updatedVideoSettings
                    break;
                default:
                    break;
                }
            }
            self.rtmpConnection.connect(self.url ?? "frog")
        }
    }
    
    @objc
    private func rtmpStatusHandler(_ notification: Notification) {
        let e = Event.from(notification)
        guard let data: ASObject = e.data as? ASObject, let code: String = data["code"] as? String else {
            return
        }
        print(e)
        
        switch code {
        case RTMPConnection.Code.connectSuccess.rawValue:
            guard let streamName: String = name else {
                eventSink([
                    "event": "error",
                    "errorDescription": "rtmp stream name is missing"
                ])
                return
            }
            rtmpStream.publish(streamName)
            retries = 0
            break
        case RTMPConnection.Code.connectFailed.rawValue, RTMPConnection.Code.connectClosed.rawValue:
            scheduleReconnect(
                errorDescription: "connection failed " + e.type.rawValue,
                terminalEvent: "error"
            )
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
        scheduleReconnect(
            errorDescription: "rtmp disconnected",
            terminalEvent: "rtmp_stopped"
        )
        
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
    public func isPaused() -> Bool{
        return rtmpStream.paused
    }
    
    
    @objc
    public func getStreamStatistics() -> NSDictionary {
        let videoSettings: VideoCodecSettings = rtmpStream.videoSettings
        let ret: NSDictionary = [
            "paused": isPaused(),
            "bitrate": videoSettings.bitRate,
            "width": Int(videoSettings.videoSize.width),
            "height": Int(videoSettings.videoSize.height),
            "fps": rtmpStream.frameRate,
            "orientation": rtmpStream.videoOrientation.rawValue
        ]
        //ret["cacheSize"] = rtmpConnection.bandWidth
        //ret["sentAudioFrames"] = rtmpCamera!!.sentAudioFrames
        //        ret["sentVideoFrames"] = rtmpCamera!!.sentVideoFrames
        //if (rtmpCamera!!.droppedAudioFrames == null) {
        //ret["droppedAudioFrames"] = 0
        //} else {
        //ret["droppedAudioFrames"] = rtmpCamera!!.droppedAudioFrames
        //}
        //ret["droppedVideoFrames"] = rtmpCamera!!.droppedVideoFrames
        //ret["isAudioMuted"] = rtmpCamera!!.isAudioMuted
        return ret
    }
    
    @objc
    public func addVideoData(buffer: CMSampleBuffer) {
        if let description = CMSampleBufferGetFormatDescription(buffer) {
            let dimensions = CMVideoFormatDescriptionGetDimensions(description)
            var videoSettings: VideoCodecSettings = rtmpStream.videoSettings
            videoSettings.videoSize = CGSize(width: Int(dimensions.width), height: Int(dimensions.height))
            videoSettings.profileLevel = kVTProfileLevel_H264_Baseline_AutoLevel as String
            videoSettings.maxKeyFrameIntervalDuration = 2
            videoSettings.bitRate = 1200 * 1024
            rtmpStream.videoSettings = videoSettings
            rtmpStream.frameRate = 24
        }
        rtmpStream.append(buffer)
    }
    
    @objc
    public func addAudioData(buffer: CMSampleBuffer) {
        rtmpStream.append(buffer)
    }
    
    @objc
    public func close() {
        rtmpConnection.close()
    }
}


class MyRTMPStreamQoSDelagate: RTMPConnectionDelegate {
    let minBitrate: Int = 300 * 1024
    let maxBitrate: Int = 2500 * 1024
    let incrementBitrate: Int = 512 * 1024

    func connection(_ connection: RTMPConnection, publishInsufficientBWOccured stream: RTMPStream) {
        let currentSettings: VideoCodecSettings = stream.videoSettings
        let videoBitrate: Int = currentSettings.bitRate

        var newVideoBitrate = videoBitrate / 2
        if newVideoBitrate < minBitrate {
            newVideoBitrate = minBitrate
        }
        print("publishInsufficientBWOccured update: \(videoBitrate) -> \(newVideoBitrate)")
        var updatedSettings: VideoCodecSettings = currentSettings
        updatedSettings.bitRate = newVideoBitrate
        stream.videoSettings = updatedSettings
    }

    func connection(_ connection: RTMPConnection, publishSufficientBWOccured stream: RTMPStream) {
        let currentSettings: VideoCodecSettings = stream.videoSettings
        let videoBitrate: Int = currentSettings.bitRate

        var newVideoBitrate = videoBitrate + incrementBitrate
        if newVideoBitrate > maxBitrate {
            newVideoBitrate = maxBitrate
        }
        print("publishSufficientBWOccured update: \(videoBitrate) -> \(newVideoBitrate)")
        var updatedSettings: VideoCodecSettings = currentSettings
        updatedSettings.bitRate = newVideoBitrate
        stream.videoSettings = updatedSettings
    }

    func connection(_ connection: RTMPConnection, updateStats stream: RTMPStream) {
    }
}
