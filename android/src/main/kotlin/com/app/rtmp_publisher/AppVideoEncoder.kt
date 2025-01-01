package com.app.rtmp_publisher

import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.HandlerThread
import android.util.Log
// REMOVIDO: android.util.Pair  (no necesitamos import Pair si no haremos destructuring)
import android.view.Surface
import androidx.annotation.RequiresApi
import com.pedro.encoder.input.video.FpsLimiter
import com.pedro.encoder.utils.CodecUtil
import com.pedro.encoder.video.FormatVideoEncoder
import com.pedro.encoder.video.GetVideoData
import java.io.IOException
import java.nio.ByteBuffer

/*
 * Encodes the data going over the wire to the backend system, ...
 */
class AppVideoEncoder(
    val getVideoData: GetVideoData,
    val width: Int,
    val height: Int,
    var fps: Int,
    var bitrate: Int,
    val rotation: Int,
    val doRotation: Boolean,
    val iFrameInterval: Int,
    val formatVideoEncoder: FormatVideoEncoder,
    // Podemos usar un profile y level, por defecto -1
    val avcProfile: Int = -1,
    val avcProfileLevel: Int = -1,
    val aspectRatio: Double = 1.0
) {
    private var spsPpsSetted = false
    var surface: Surface? = null
    private val fpsLimiter: FpsLimiter = FpsLimiter()
    var type: String = CodecUtil.H264_MIME
    private var handlerThread: HandlerThread = HandlerThread(TAG)
    protected var codec: MediaCodec? = null
    private var callback: MediaCodec.Callback? = null
    private var isBufferMode: Boolean = false
    protected var presentTimeUs: Long = 0
    var force: CodecUtil.Force = CodecUtil.Force.FIRST_COMPATIBLE_FOUND
    private val bufferInfo: MediaCodec.BufferInfo = MediaCodec.BufferInfo()

    @Volatile
    var running = false
    var limitFps = fps

    // Ajustes de rotación para ancho/alto si doRotation es true
    private fun computeResolution(): Pair<Int, Int> {
        var ratioWidth = width
        var ratioHeight = height
        // if (doRotation && (rotation == 90 || rotation == 270)) {
        //   ratioWidth = height
        //   ratioHeight = width
        // }
        return Pair(ratioWidth, ratioHeight)
    }

    fun prepare(): Boolean {
        val encoder = chooseEncoder(type)
        if (encoder == null) {
            Log.e(TAG, "Valid encoder not found")
            return false
        }
        try {
            codec = MediaCodec.createByCodecName(encoder.name)
        } catch (e: IOException) {
            Log.e(TAG, "Create VideoEncoder failed.", e)
            return false
        } catch (e: IllegalStateException) {
            Log.e(TAG, "Create VideoEncoder failed (IllegalStateException).", e)
            return false
        }

        // ***** CAMBIO: En vez de destructuring val (ratioWidth, ratioHeight) = computeResolution() *****
        val resolution = computeResolution()
        val ratioWidth = resolution.first
        val ratioHeight = resolution.second
        // *****************************************************

        val videoFormat: MediaFormat = MediaFormat.createVideoFormat(type, ratioWidth, ratioHeight)

        Log.i(TAG, "Prepare video info: ${encoder.name}, ${ratioWidth}x${ratioHeight}")
        videoFormat.setInteger(MediaFormat.KEY_COLOR_FORMAT, formatVideoEncoder.getFormatCodec())
        videoFormat.setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, 0)

        // Ajustar bitrate (ej. 3.5Mbps)
        videoFormat.setInteger(MediaFormat.KEY_BIT_RATE, bitrate)
        // fps
        videoFormat.setInteger(MediaFormat.KEY_FRAME_RATE, fps)
        // keyframe interval
        videoFormat.setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, iFrameInterval)

        // rotación si doRotation
        if (doRotation) {
            videoFormat.setInteger(MediaFormat.KEY_ROTATION, rotation)
        }

        // Si pasamos avcProfile y avcProfileLevel (H.264 High@Level4)
        if (this.avcProfile > 0 && this.avcProfileLevel > 0) {
            videoFormat.setInteger(MediaFormat.KEY_PROFILE, this.avcProfile)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                videoFormat.setInteger(MediaFormat.KEY_LEVEL, this.avcProfileLevel)
            }
        }

        Log.i(TAG, "bitrate=$bitrate, fps=$fps, iFrameInterval=$iFrameInterval, rotation=$rotation, doRotation=$doRotation")

        codec!!.configure(videoFormat, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        running = false
        isBufferMode = false

        surface = codec!!.createInputSurface()
        Log.i(TAG, "prepared")
        return true
    }

    fun start() {
        spsPpsSetted = false
        presentTimeUs = System.nanoTime() / 1000
        fpsLimiter.setFPS(limitFps)

        handlerThread.start()
        val handler = Handler(handlerThread.looper)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            createAsyncCallback()
            codec!!.setCallback(callback, handler)
            codec!!.start()
        } else {
            codec!!.start()
            handler.post {
                while (running) {
                    try {
                        getDataFromEncoder()
                    } catch (e: IllegalStateException) {
                        Log.i(TAG, "Encoding error", e)
                    }
                }
            }
        }
        running = true
        Log.i(TAG, "started")
    }

    protected fun stopImp() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR2) {
            handlerThread.quitSafely()
        } else {
            handlerThread.quit()
        }
        spsPpsSetted = false
        surface = null
        Log.i(TAG, "stopped")
    }

    fun stop() {
        running = false
        try {
            codec?.stop()
            codec?.release()
            stopImp()
            codec = null
        } catch (e: IllegalStateException) {
            codec = null
        } catch (e: NullPointerException) {
            codec = null
        }
    }

    fun reset() {
        stop()
        prepare()
        start()
    }

    @RequiresApi(api = Build.VERSION_CODES.KITKAT)
    fun setVideoBitrateOnFly(bitrate: Int) {
        if (running) {
            this.bitrate = bitrate
            val bundle = Bundle()
            bundle.putInt(MediaCodec.PARAMETER_KEY_VIDEO_BITRATE, bitrate)
            try {
                codec!!.setParameters(bundle)
            } catch (e: IllegalStateException) {
                Log.e(TAG, "encoder need be running", e)
            }
        }
    }

    @RequiresApi(api = Build.VERSION_CODES.KITKAT)
    fun forceSyncFrame() {
        if (running) {
            val bundle = Bundle()
            bundle.putInt(MediaCodec.PARAMETER_KEY_REQUEST_SYNC_FRAME, 0)
            try {
                codec!!.setParameters(bundle)
            } catch (e: IllegalStateException) {
                Log.e(TAG, "encoder need be running", e)
            }
        }
    }

    private fun sendSPSandPPS(mediaFormat: MediaFormat) {
        if (type == CodecUtil.H265_MIME) {
            // H265
            val csd0 = mediaFormat.getByteBuffer("csd-0") ?: return
            val byteBufferList = extractVpsSpsPpsFromH265(csd0)
            getVideoData.onSpsPpsVps(byteBufferList[1], byteBufferList[2], byteBufferList[0])
        } else {
            // H264
            val csd0 = mediaFormat.getByteBuffer("csd-0")
            val csd1 = mediaFormat.getByteBuffer("csd-1")
            getVideoData.onSpsPps(csd0, csd1)
        }
    }

    private fun extractVpsSpsPpsFromH265(csd0byteBuffer: ByteBuffer): List<ByteBuffer> {
        val byteBufferList: MutableList<ByteBuffer> = mutableListOf()
        val csdArray: ByteArray = csd0byteBuffer.array()
        var vpsPosition = -1
        var spsPosition = -1
        var ppsPosition = -1
        var contBufferInitiation = 0
        for (i in csdArray.indices) {
            if (contBufferInitiation == 3 && csdArray[i].toInt() == 1) {
                if (vpsPosition == -1) {
                    vpsPosition = i - 3
                } else if (spsPosition == -1) {
                    spsPosition = i - 3
                } else {
                    ppsPosition = i - 3
                }
            }
            if (csdArray[i].toInt() == 0) {
                contBufferInitiation++
            } else {
                contBufferInitiation = 0
            }
        }
        val vps = ByteArray(spsPosition)
        val sps = ByteArray(ppsPosition - spsPosition)
        val pps = ByteArray(csdArray.size - ppsPosition)
        for (i in csdArray.indices) {
            if (i < spsPosition) {
                vps[i] = csdArray[i]
            } else if (i < ppsPosition) {
                sps[i - spsPosition] = csdArray[i]
            } else {
                pps[i - ppsPosition] = csdArray[i]
            }
        }
        byteBufferList.add(ByteBuffer.wrap(vps))
        byteBufferList.add(ByteBuffer.wrap(sps))
        byteBufferList.add(ByteBuffer.wrap(pps))
        return byteBufferList
    }

    private fun decodeSpsPpsFromBuffer(
        outputBuffer: ByteBuffer,
        length: Int
    ): Pair<ByteBuffer, ByteBuffer>? {
        val csd = ByteArray(length)
        outputBuffer.get(csd, 0, length)
        var spsIndex = -1
        var ppsIndex = -1
        var i = 0
        while (i < length - 4) {
            if (csd[i].toInt() == 0 && csd[i + 1].toInt() == 0 && csd[i + 2].toInt() == 0 && csd[i + 3].toInt() == 1) {
                if (spsIndex == -1) {
                    spsIndex = i
                } else {
                    ppsIndex = i
                    break
                }
            }
            i++
        }
        if (spsIndex != -1 && ppsIndex != -1) {
            val mSPS = ByteArray(ppsIndex)
            System.arraycopy(csd, spsIndex, mSPS, 0, ppsIndex)
            val mPPS = ByteArray(length - ppsIndex)
            System.arraycopy(csd, ppsIndex, mPPS, 0, length - ppsIndex)
            return Pair(ByteBuffer.wrap(mSPS), ByteBuffer.wrap(mPPS))
        }
        return null
    }

    @Throws(IllegalStateException::class)
    protected fun getDataFromEncoder() {
        while (running) {
            val outBufferIndex = codec!!.dequeueOutputBuffer(bufferInfo, 1)
            if (outBufferIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                val mediaFormat: MediaFormat = codec!!.outputFormat
                formatChanged(codec!!, mediaFormat)
            } else if (outBufferIndex >= 0) {
                outputAvailable(codec!!, outBufferIndex, bufferInfo)
            } else {
                break
            }
        }
    }

    fun formatChanged(mediaCodec: MediaCodec, mediaFormat: MediaFormat) {
        getVideoData.onVideoFormat(mediaFormat)
        sendSPSandPPS(mediaFormat)
        spsPpsSetted = true
    }

    protected fun checkBuffer(byteBuffer: ByteBuffer, bufferInfo: MediaCodec.BufferInfo) {
        if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0) {
            if (!spsPpsSetted) {
                val buffers = decodeSpsPpsFromBuffer(byteBuffer.duplicate(), bufferInfo.size)
                if (buffers != null) {
                    getVideoData.onSpsPps(buffers.first, buffers.second)
                    spsPpsSetted = true
                }
            }
        }
    }

    protected fun sendBuffer(byteBuffer: ByteBuffer, bufferInfo: MediaCodec.BufferInfo) {
        bufferInfo.presentationTimeUs = System.nanoTime() / 1000 - presentTimeUs
        getVideoData.getVideoData(byteBuffer, bufferInfo)
    }

    @Throws(IllegalStateException::class)
    private fun processOutput(
        byteBuffer: ByteBuffer,
        mediaCodec: MediaCodec,
        outBufferIndex: Int,
        bufferInfo: MediaCodec.BufferInfo
    ) {
        if (running) {
            checkBuffer(byteBuffer, bufferInfo)
            sendBuffer(byteBuffer, bufferInfo)
        }
        mediaCodec.releaseOutputBuffer(outBufferIndex, false)
    }

    @RequiresApi(api = Build.VERSION_CODES.M)
    private fun createAsyncCallback() {
        callback = object : MediaCodec.Callback() {
            override fun onInputBufferAvailable(mediaCodec: MediaCodec, inBufferIndex: Int) {
                // Not used with surface input
            }
            override fun onOutputBufferAvailable(
                mediaCodec: MediaCodec,
                outBufferIndex: Int,
                bufferInfo: MediaCodec.BufferInfo
            ) {
                try {
                    outputAvailable(mediaCodec, outBufferIndex, bufferInfo)
                } catch (e: IllegalStateException) {
                    Log.i(TAG, "Encoding error", e)
                }
            }
            override fun onError(mediaCodec: MediaCodec, e: MediaCodec.CodecException) {
                Log.e(TAG, "Error", e)
            }
            override fun onOutputFormatChanged(mediaCodec: MediaCodec, mediaFormat: MediaFormat) {
                formatChanged(mediaCodec, mediaFormat)
            }
        }
    }

    fun outputAvailable(
        mediaCodec: MediaCodec,
        outBufferIndex: Int,
        bufferInfo: MediaCodec.BufferInfo
    ) {
        val byteBuffer: ByteBuffer? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            mediaCodec.getOutputBuffer(outBufferIndex)
        } else {
            mediaCodec.outputBuffers[outBufferIndex]
        }
        if (byteBuffer != null) {
            processOutput(byteBuffer, mediaCodec, outBufferIndex, bufferInfo)
        }
    }

    protected fun chooseEncoder(mime: String): MediaCodecInfo? {
        val mediaCodecInfoList = when (force) {
            CodecUtil.Force.HARDWARE -> CodecUtil.getAllHardwareEncoders(mime)
            CodecUtil.Force.SOFTWARE -> CodecUtil.getAllSoftwareEncoders(mime)
            else -> CodecUtil.getAllEncoders(mime)
        }
        for (mci in mediaCodecInfoList) {
            Log.i(TAG, "VideoEncoder " + mci.name)
            val codecCapabilities = mci.getCapabilitiesForType(mime)
            for (color in codecCapabilities.colorFormats) {
                Log.i(TAG, "Color supported: $color")
                if (formatVideoEncoder == FormatVideoEncoder.SURFACE) {
                    if (color == FormatVideoEncoder.SURFACE.formatCodec) {
                        return mci
                    }
                } else {
                    // YUV420
                    if (color == FormatVideoEncoder.YUV420PLANAR.formatCodec ||
                        color == FormatVideoEncoder.YUV420SEMIPLANAR.formatCodec
                    ) {
                        return mci
                    }
                }
            }
        }
        return null
    }

    companion object {
        private const val TAG = "AppVideoEncoder"
    }
}
