import Foundation

class NALParser {
    private let h264StartCode3: [UInt8] = [0x00, 0x00, 0x01]
    private let h264StartCode4: [UInt8] = [0x00, 0x00, 0x00, 0x01]
    
    func parseAnnexBStream(_ data: Data) -> [NALUnit] {
        var units: [NALUnit] = []
        var offset = 0
        
        while offset < data.count {
            guard let (startCodeLen, nalStart) = findStartCode(in: data, offset: offset) else {
                break
            }
            
            let nalOffset = nalStart + startCodeLen
            let nextStart = findNextStartCode(in: data, offset: nalOffset) ?? data.count
            
            let nalData = data.subdata(in: nalOffset..<nextStart)
            if !nalData.isEmpty {
                let typeValue = nalData[0] & 0x1F
                if let type = NALUnitType(rawValue: typeValue) {
                    units.append(NALUnit(
                        type: type,
                        data: nalData,
                        startCodeLength: startCodeLen
                    ))
                }
            }
            
            offset = nextStart
        }
        if !data.isEmpty && units.isEmpty {
            Task {
                await DebugCategory.decoder.warningLog(
                    "No H264 NAL units parsed",
                    context: ["bytes": String(data.count)]
                )
            }
        }
        return units
    }
    
    func parseHEVCAnnexBStream(_ data: Data) -> [HEVCNALUnit] {
        var units: [HEVCNALUnit] = []
        var offset = 0
        
        while offset < data.count {
            guard let (startCodeLen, nalStart) = findStartCode(in: data, offset: offset) else {
                break
            }
            
            let nalOffset = nalStart + startCodeLen
            let nextStart = findNextStartCode(in: data, offset: nalOffset) ?? data.count
            
            let nalData = data.subdata(in: nalOffset..<nextStart)
            if nalData.count >= 2 {
                let typeValue = (nalData[0] >> 1) & 0x3F
                if let type = HEVCNALUnitType(rawValue: typeValue) {
                    units.append(HEVCNALUnit(
                        type: type,
                        data: nalData,
                        startCodeLength: startCodeLen
                    ))
                }
            }
            
            offset = nextStart
        }
        if !data.isEmpty && units.isEmpty {
            Task {
                await DebugCategory.decoder.warningLog(
                    "No HEVC NAL units parsed",
                    context: ["bytes": String(data.count)]
                )
            }
        }
        return units
    }
    
    private func findStartCode(in data: Data, offset: Int) -> (length: Int, position: Int)? {
        if offset >= data.count { return nil }
        
        let searchData = data.subdata(in: offset..<data.count)
        
        if searchData.count >= 4 &&
           searchData[0] == 0x00 && searchData[1] == 0x00 &&
           searchData[2] == 0x00 && searchData[3] == 0x01 {
            return (4, offset)
        }
        
        if searchData.count >= 3 &&
           searchData[0] == 0x00 && searchData[1] == 0x00 &&
           searchData[2] == 0x01 {
            return (3, offset)
        }
        
        var i = 0
        while i < searchData.count - 2 {
            if searchData[i] == 0x00 && searchData[i + 1] == 0x00 {
                if i + 3 < searchData.count && searchData[i + 3] == 0x01 {
                    return (4, offset + i)
                }
                if i + 2 < searchData.count && searchData[i + 2] == 0x01 {
                    return (3, offset + i)
                }
            }
            i += 1
        }
        
        return nil
    }
    
    private func findNextStartCode(in data: Data, offset: Int) -> Int? {
        if offset >= data.count { return nil }
        
        let searchData = data.subdata(in: offset..<data.count)
        
        var i = 0
        while i < searchData.count - 2 {
            if searchData[i] == 0x00 && searchData[i + 1] == 0x00 {
                if i + 3 < searchData.count && searchData[i + 3] == 0x01 {
                    return offset + i
                }
                if i + 2 < searchData.count && searchData[i + 2] == 0x01 {
                    return offset + i
                }
            }
            i += 1
        }
        
        return nil
    }
    
    func stripStartCode(from nalUnit: NALUnit) -> Data {
        if nalUnit.startCodeLength > 0 && nalUnit.data.count > 0 {
            return nalUnit.data
        }
        return nalUnit.data
    }
}
