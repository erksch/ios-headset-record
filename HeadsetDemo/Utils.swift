import AVFAudio

enum SoundError: Error {
    case fileNotFound
}

func getSoundFile(name: String) throws -> AVAudioFile {
    guard let soundFileURL = Bundle.main.url(
            forResource: name,
            withExtension: "wav"
    ) else {
        throw SoundError.fileNotFound
    }

    return try AVAudioFile(forReading: soundFileURL, commonFormat: .pcmFormatInt16, interleaved: true)
}

enum AudioConversionError: Error {
    case unableToCreateConvertedBuffer
    case unableToCreateConverter
    case conversionFailed
}

func convertBufferToFormat(buffer: AVAudioPCMBuffer, outputFormat: AVAudioFormat) throws -> AVAudioPCMBuffer {
    let inputFormat = buffer.format
    let convertedFrameCapacity = Int(outputFormat.sampleRate) * Int(buffer.frameLength) / Int(inputFormat.sampleRate)
    
    guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: AVAudioFrameCount(convertedFrameCapacity)) else {
        throw AudioConversionError.unableToCreateConvertedBuffer
    }
    
    convertedBuffer.frameLength = buffer.frameCapacity
    
    guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
        throw AudioConversionError.unableToCreateConverter
    }
    
    var error : NSError?
    
    converter.convert(to: convertedBuffer, error: &error, withInputFrom: { inNumPackets, outStatus in
        outStatus.pointee = AVAudioConverterInputStatus.haveData
        return buffer
    })
    
    if (error != nil) {
        throw AudioConversionError.conversionFailed
    }
    
    return convertedBuffer
}

