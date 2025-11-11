package com.notetaking.note_taking_ai

import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.nio.ByteBuffer

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.notetaking.note_taking_ai/audio"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "decodeToWav" -> {
                    val inputPath = call.argument<String>("inputPath")
                    val sampleRate = call.argument<Int>("sampleRate") ?: 16000
                    val channels = call.argument<Int>("channels") ?: 1

                    if (inputPath != null) {
                        try {
                            val wavPath = decodeToWav(inputPath, sampleRate, channels)
                            result.success(wavPath)
                        } catch (e: Exception) {
                            result.error("DECODE_ERROR", "Failed to decode: ${e.message}", null)
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "inputPath is required", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun decodeToWav(inputPath: String, targetSampleRate: Int, targetChannels: Int): String {
        val extractor = MediaExtractor()
        extractor.setDataSource(inputPath)

        // Find audio track
        var trackIndex = -1
        for (i in 0 until extractor.trackCount) {
            val format = extractor.getTrackFormat(i)
            val mime = format.getString(MediaFormat.KEY_MIME)
            if (mime?.startsWith("audio/") == true) {
                trackIndex = i
                break
            }
        }

        if (trackIndex < 0) {
            throw Exception("No audio track found")
        }

        extractor.selectTrack(trackIndex)
        val format = extractor.getTrackFormat(trackIndex)
        val mime = format.getString(MediaFormat.KEY_MIME) ?: throw Exception("No MIME type")

        // Create decoder
        val decoder = MediaCodec.createDecoderByType(mime)
        decoder.configure(format, null, null, 0)
        decoder.start()

        val pcmData = mutableListOf<Byte>()
        val bufferInfo = MediaCodec.BufferInfo()
        var isEOS = false

        while (!isEOS) {
            // Feed input
            val inputBufferId = decoder.dequeueInputBuffer(10000)
            if (inputBufferId >= 0) {
                val inputBuffer = decoder.getInputBuffer(inputBufferId)
                val sampleSize = extractor.readSampleData(inputBuffer!!, 0)

                if (sampleSize < 0) {
                    decoder.queueInputBuffer(inputBufferId, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                    isEOS = true
                } else {
                    val presentationTimeUs = extractor.sampleTime
                    decoder.queueInputBuffer(inputBufferId, 0, sampleSize, presentationTimeUs, 0)
                    extractor.advance()
                }
            }

            // Get output
            val outputBufferId = decoder.dequeueOutputBuffer(bufferInfo, 10000)
            if (outputBufferId >= 0) {
                val outputBuffer = decoder.getOutputBuffer(outputBufferId)
                if (bufferInfo.size > 0 && outputBuffer != null) {
                    val chunk = ByteArray(bufferInfo.size)
                    outputBuffer.get(chunk)
                    pcmData.addAll(chunk.toList())
                }
                decoder.releaseOutputBuffer(outputBufferId, false)

                if ((bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                    isEOS = true
                }
            }
        }

        decoder.stop()
        decoder.release()
        extractor.release()

        // Write WAV file
        val wavPath = inputPath.replace(Regex("\\.[^.]+$"), ".wav")
        writeWavFile(wavPath, pcmData.toByteArray(), targetSampleRate, targetChannels)

        return wavPath
    }

    private fun writeWavFile(path: String, pcmData: ByteArray, sampleRate: Int, channels: Int) {
        val outputFile = File(path)
        val outputStream = FileOutputStream(outputFile)

        val bitsPerSample = 16
        val byteRate = sampleRate * channels * bitsPerSample / 8
        val blockAlign = channels * bitsPerSample / 8
        val dataSize = pcmData.size
        val fileSize = 36 + dataSize

        // Write WAV header
        outputStream.write("RIFF".toByteArray())
        outputStream.write(intToBytes(fileSize))
        outputStream.write("WAVE".toByteArray())

        // fmt chunk
        outputStream.write("fmt ".toByteArray())
        outputStream.write(intToBytes(16)) // fmt chunk size
        outputStream.write(shortToBytes(1)) // audio format (PCM)
        outputStream.write(shortToBytes(channels))
        outputStream.write(intToBytes(sampleRate))
        outputStream.write(intToBytes(byteRate))
        outputStream.write(shortToBytes(blockAlign))
        outputStream.write(shortToBytes(bitsPerSample))

        // data chunk
        outputStream.write("data".toByteArray())
        outputStream.write(intToBytes(dataSize))
        outputStream.write(pcmData)

        outputStream.close()
    }

    private fun intToBytes(value: Int): ByteArray {
        return byteArrayOf(
            (value and 0xFF).toByte(),
            ((value shr 8) and 0xFF).toByte(),
            ((value shr 16) and 0xFF).toByte(),
            ((value shr 24) and 0xFF).toByte()
        )
    }

    private fun shortToBytes(value: Int): ByteArray {
        return byteArrayOf(
            (value and 0xFF).toByte(),
            ((value shr 8) and 0xFF).toByte()
        )
    }
}
