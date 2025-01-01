package com.app.rtmp_publisher

import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.os.Build
import android.util.Log
import android.util.SparseIntArray
import android.view.Surface
import androidx.annotation.RequiresApi
import com.pedro.encoder.Frame
import com.pedro.encoder.audio.AudioEncoder
import com.pedro.encoder.audio.GetAacData
import com.pedro.encoder.input.audio.CustomAudioEffect
import com.pedro.encoder.input.audio.GetMicrophoneData
import com.pedro.encoder.input.audio.MicrophoneManager
import com.pedro.encoder.utils.CodecUtil
import com.pedro.encoder.video.FormatVideoEncoder
import com.pedro.encoder.video.GetVideoData
import com.pedro.rtplibrary.util.FpsListener
import com.pedro.rtplibrary.util.RecordController
import com.pedro.rtplibrary.view.OffScreenGlThread
import net.ossrs.rtmp.ConnectCheckerRtmp
import net.ossrs.rtmp.SrsFlvMuxer
import java.nio.ByteBuffer

@RequiresApi(api = Build.VERSION_CODES.LOLLIPOP)
class RtmpCameraConnector(
    val context: android.content.Context,
    val useOpenGL: Boolean,
    val isPortrait: Boolean,
    val connectChecker: ConnectCheckerRtmp
) : GetAacData,
    GetVideoData,
    GetMicrophoneData,
    FpsListener.Callback,
    RecordController.Listener,
    ConnectCheckerRtmp {

    private var videoEncoder: AppVideoEncoder? = null
    private val microphoneManager: MicrophoneManager = MicrophoneManager(this)
    private val audioEncoder: AudioEncoder = AudioEncoder(this)
    private val srsFlvMuxer: SrsFlvMuxer = SrsFlvMuxer(this)
    private var curFps: Int = 0
    private var pausedStreaming: Boolean = false
    private var pausedRecording: Boolean = false
    private val glInterface: OffScreenGlThread = OffScreenGlThread(context)
    private val recordController: RecordController = RecordController()
    var isStreaming = false
        private set
    var isRecording = false
        private set
    private val fpsListener = FpsListener()

    // Rotations map
    private val ORIENTATIONS: SparseIntArray = SparseIntArray(4)

    init {
        fpsListener.setCallback(this)
        if (useOpenGL) {
            glInterface.init()
        }
        ORIENTATIONS.append(0, 270)
        ORIENTATIONS.append(90, 0)
        ORIENTATIONS.append(180, 90)
        ORIENTATIONS.append(270, 180) // Dependiendo tu caso
        // Nota: Podrías ajustarlo si tu device rota distinto.
    }

    // ADDED/EDITED: prepareVideo con defaults => 1080p, 30 fps, 3.5 Mbps, etc.
    fun prepareVideo(
        width: Int = 1920,  // ADDED/EDITED
        height: Int = 1080, // ADDED/EDITED
        fps: Int = 30,      // ADDED/EDITED
        bitrate: Int = 3500 * 1024,  // ADDED/EDITED (~3.5 Mbps)
        hardwareRotation: Boolean,
        iFrameInterval: Int = 2,
        rotation: Int,
        aspectRatio: Double = 1.0
    ): Boolean {
        pausedStreaming = false
        pausedRecording = false

        // ADDED/EDITED: Forzar perfil High@Level4 si se desea
        val profile = MediaCodecInfo.CodecProfileLevel.AVCProfileHigh
        val level   = MediaCodecInfo.CodecProfileLevel.AVCLevel4

        videoEncoder = AppVideoEncoder(
            getVideoData = this,
            width = width,
            height = height,
            fps = fps,
            bitrate = bitrate,
            rotation = if (useOpenGL) 0 else rotation,
            doRotation = hardwareRotation,
            iFrameInterval = iFrameInterval,
            formatVideoEncoder = FormatVideoEncoder.SURFACE,
            avcProfile = profile,        // ADDED/EDITED
            avcProfileLevel = level,     // ADDED/EDITED
            aspectRatio = aspectRatio
        )

        val result = videoEncoder!!.prepare()
        if (useOpenGL) {
            prepareGlInterface(ORIENTATIONS[rotation], aspectRatio)
            glInterface.addMediaCodecSurface(videoEncoder!!.surface)
        }
        return result
    }

    private fun prepareGlInterface(rotation: Int, aspectRatio: Double) {
        Log.i(TAG, "prepareGlInterface rotation=$rotation isPortrait=$isPortrait")
        glInterface.setEncoderSize(videoEncoder!!.width, videoEncoder!!.height)
        glInterface.setRotation(rotation)
        glInterface.start()
    }

    fun prepareAudio(
        bitrate: Int = 64 * 1024,
        sampleRate: Int = 32000,
        isStereo: Boolean = true,
        echoCanceler: Boolean = false,
        noiseSuppressor: Boolean = false
    ): Boolean {
        microphoneManager.createMicrophone(sampleRate, isStereo, echoCanceler, noiseSuppressor)
        srsFlvMuxer.setIsStereo(isStereo)
        srsFlvMuxer.setSampleRate(sampleRate)
        return audioEncoder.prepareAudioEncoder(bitrate, sampleRate, isStereo, microphoneManager.maxInputSize)
    }

    fun startStream(url: String) {
        if (!isStreaming) {
            isStreaming = true
            startStreamRtp(url)
        }
    }

    fun stopStream() {
        if (isStreaming) {
            isStreaming = false
            stopStreamRtp()
        }
        if (!isRecording) {
            microphoneManager.stop()
            videoEncoder?.stop()
            audioEncoder.stop()
            if (useOpenGL) glInterface.stop()
        }
    }

    fun startRecord(path: String) {
        if (!isRecording) {
            recordController.startRecord(path, this)
            isRecording = true
            if (!isStreaming) {
                // Si no se estaba streameando, tenemos que iniciar encoders:
                startEncoders()
            }
        }
    }

    fun stopRecord() {
        if (isRecording) {
            recordController.stopRecord()
        }
        isRecording = false
        if (!isStreaming) {
            stopStream()
        }
    }

    fun startVideoRecordingAndStreaming(filePath: String, url: String) {
        // Ejemplo
        startStream(url)
        startRecord(filePath)
    }

    fun pauseVideoRecording() {
        pausedRecording = true
        videoEncoder?.forceSyncFrame()
    }

    fun resumeVideoRecording() {
        pausedRecording = false
    }

    fun pauseVideoStreaming() {
        pausedStreaming = true
    }

    fun resumeVideoStreaming() {
        pausedStreaming = false
    }

    fun startEncoders() {
        audioEncoder.start()
        microphoneManager.start()
        videoEncoder?.start()
    }

    private fun startStreamRtp(url: String) {
        // Ajustar resolución de Muxer
        if (videoEncoder!!.rotation == 90 || videoEncoder!!.rotation == 270) {
            srsFlvMuxer.setVideoResolution(videoEncoder!!.height, videoEncoder!!.width)
        } else {
            srsFlvMuxer.setVideoResolution(videoEncoder!!.width, videoEncoder!!.height)
        }
        srsFlvMuxer.start(url)
        // Si no estaban corriendo, arrancar
        if (!audioEncoder.isRunning) startEncoders()
    }

    private fun stopStreamRtp() {
        srsFlvMuxer.stop()
    }

    fun setCustomAudioEffect(customAudioEffect: CustomAudioEffect?) {
        microphoneManager.setCustomAudioEffect(customAudioEffect)
    }

    fun disableAudio() {
        microphoneManager.mute()
    }

    fun enableAudio() {
        microphoneManager.unMute()
    }

    val isAudioMuted: Boolean
        get() = microphoneManager.isMuted

    fun setVideoBitrateOnFly(bitrate: Int) {
        videoEncoder?.setVideoBitrateOnFly(bitrate)
    }

    fun setLimitFPSOnFly(fps: Int) {
        videoEncoder?.limitFps = fps
    }

    // region Overrides: GetAacData, GetVideoData, etc.

    override fun getAacData(aacBuffer: ByteBuffer, info: MediaCodec.BufferInfo) {
        if (isStreaming && !pausedStreaming) {
            srsFlvMuxer.sendAudio(aacBuffer, info)
        }
        if (isRecording && !pausedRecording) {
            recordController.recordAudio(aacBuffer, info)
        }
    }

    override fun onSpsPps(sps: ByteBuffer?, pps: ByteBuffer?) {
        if (isStreaming && !pausedStreaming) {
            srsFlvMuxer.setSpsPPs(sps, pps)
        }
    }

    override fun onSpsPpsVps(sps: ByteBuffer?, pps: ByteBuffer?, vps: ByteBuffer?) {
        if (isStreaming && !pausedStreaming) {
            srsFlvMuxer.setSpsPPs(sps, pps)
        }
    }

    override fun getVideoData(h264Buffer: ByteBuffer, info: MediaCodec.BufferInfo) {
        fpsListener.calculateFps()
        if (isStreaming && !pausedStreaming) {
            srsFlvMuxer.sendVideo(h264Buffer, info)
        }
        if (isRecording && !pausedRecording) {
            recordController.recordVideo(h264Buffer, info)
        }
    }

    override fun onVideoFormat(mediaFormat: MediaFormat) {
        recordController.setVideoFormat(mediaFormat)
    }

    override fun onAudioFormat(mediaFormat: MediaFormat) {
        recordController.setAudioFormat(mediaFormat)
    }

    override fun inputPCMData(frame: com.pedro.encoder.Frame) {
        audioEncoder.inputPCMData(frame)
    }

    override fun onFps(fps: Int) {
        curFps = fps
    }

    override fun onStatusChange(status: RecordController.Status) {
        Log.d(TAG, "Recorder status: $status")
    }

    // endregion

    // region ConnectCheckerRtmp

    override fun onConnectionSuccessRtmp() {
        if (!videoEncoder!!.running) {
            startEncoders()
        }
        connectChecker.onConnectionSuccessRtmp()
    }

    override fun onConnectionFailedRtmp(reason: String) {
        connectChecker.onConnectionFailedRtmp(reason)
    }

    override fun onNewBitrateRtmp(bitrate: Long) {
        connectChecker.onNewBitrateRtmp(bitrate)
    }

    override fun onDisconnectRtmp() {
        connectChecker.onDisconnectRtmp()
    }

    override fun onAuthErrorRtmp() {
        connectChecker.onAuthErrorRtmp()
    }

    override fun onAuthSuccessRtmp() {
        connectChecker.onAuthSuccessRtmp()
    }

    // endregion

    companion object {
        private const val TAG = "RtmpCameraConnector"
    }
}
