import Foundation

enum NALUnitType: UInt8 {
    case unspecified = 0
    case codeNonIDRSlice = 1
    case codePartitionA = 2
    case codePartitionB = 3
    case codePartitionC = 4
    case codeIDRSlice = 5
    case sei = 6
    case sps = 7
    case pps = 8
    case aud = 9
    case eosds = 10
    case eostream = 11
    case fillerData = 12
    case spsExt = 13
    case prefixNAL = 14
    case subsetSPS = 15
    case depthParameterSet = 16
    case codeExtSlice = 20
    
    var description: String {
        switch self {
        case .unspecified:
            return "Unspecified"
        case .codeNonIDRSlice:
            return "Non-IDR Slice"
        case .codePartitionA:
            return "Partition A"
        case .codePartitionB:
            return "Partition B"
        case .codePartitionC:
            return "Partition C"
        case .codeIDRSlice:
            return "IDR Slice"
        case .sei:
            return "SEI"
        case .sps:
            return "SPS"
        case .pps:
            return "PPS"
        case .aud:
            return "AUD"
        case .eosds:
            return "EOSDS"
        case .eostream:
            return "EO Stream"
        case .fillerData:
            return "Filler Data"
        case .spsExt:
            return "SPS Ext"
        case .prefixNAL:
            return "Prefix NAL"
        case .subsetSPS:
            return "Subset SPS"
        case .depthParameterSet:
            return "Depth Parameter Set"
        case .codeExtSlice:
            return "Ext Slice"
        }
    }
}

struct NALUnit {
    let type: NALUnitType
    let data: Data
    let startCodeLength: Int // 3 (0x000001) or 4 (0x00000001)
    
    var forbiddenBit: Bool {
        if data.isEmpty { return false }
        return (data[0] & 0x80) != 0
    }
    
    var refIDC: UInt8 {
        if data.isEmpty { return 0 }
        return (data[0] & 0x60) >> 5
    }
    
    var isIDR: Bool {
        return type == .codeIDRSlice
    }
    
    var isParameterSet: Bool {
        return type == .sps || type == .pps
    }
    
    var isSEI: Bool {
        return type == .sei
    }
}

// MARK: - HEVC NAL Unit Type

enum HEVCNALUnitType: UInt8 {
    case codeTrailN = 0
    case codeTrailR = 1
    case codeIslN = 2
    case codeIslR = 3
    case codeBlaWLP = 4
    case codeBlaWRadl = 5
    case codeBlaIdrWRadl = 6
    case codeIdrWRadl = 7
    case codeIdrNLP = 8
    case codeVps = 32
    case codeSps = 33
    case codePps = 34
    case codeAud = 35
    case codeEosVps = 36
    case codeEosBitstreamNalUnit = 37
    case codeEosNalUnitNalUnit = 38
    case codeFillerData = 39
    case codePrefixSei = 40
    case codeSuffixSei = 41
    
    var description: String {
        switch self {
        case .codeTrailN:
            return "TRAIL_N"
        case .codeTrailR:
            return "TRAIL_R"
        case .codeIslN:
            return "ISL_N"
        case .codeIslR:
            return "ISL_R"
        case .codeBlaWLP:
            return "BLA_W_LP"
        case .codeBlaWRadl:
            return "BLA_W_RADL"
        case .codeBlaIdrWRadl:
            return "BLA_IDR_W_RADL"
        case .codeIdrWRadl:
            return "IDR_W_RADL"
        case .codeIdrNLP:
            return "IDR_NLP"
        case .codeVps:
            return "VPS"
        case .codeSps:
            return "SPS"
        case .codePps:
            return "PPS"
        case .codeAud:
            return "AUD"
        case .codeEosVps:
            return "EOS_VPS"
        case .codeEosBitstreamNalUnit:
            return "EOS_BITSTREAM"
        case .codeEosNalUnitNalUnit:
            return "EOS_NAL_UNIT"
        case .codeFillerData:
            return "FILLER_DATA"
        case .codePrefixSei:
            return "PREFIX_SEI"
        case .codeSuffixSei:
            return "SUFFIX_SEI"
        }
    }
    
    var isParameterSet: Bool {
        return self == .codeVps || self == .codeSps || self == .codePps
    }
}

struct HEVCNALUnit {
    let type: HEVCNALUnitType
    let data: Data
    let startCodeLength: Int
    
    var forbiddenBit: Bool {
        if data.isEmpty { return false }
        return (data[0] & 0x80) != 0
    }
    
    var nuhLayerId: UInt8 {
        if data.count < 2 { return 0 }
        return (data[1] & 0x78) >> 3
    }
    
    var nuhTemporalIdPlus1: UInt8 {
        if data.isEmpty { return 0 }
        return data[1] & 0x07
    }
}
