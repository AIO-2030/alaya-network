// 测试WiFi解析功能
// 基于实际日志数据：c6 48 33 43 5f 34 30 31 07 bd 34 30 31 34

function parseWiFiNetworksFromPayload(payloadData) {
  const networks = [];
  
  try {
    console.log('📋 Parsing WiFi networks from payload data');
    console.log('Payload length:', payloadData.length, 'bytes');
    console.log('Payload (hex):', Array.from(payloadData).map(b => b.toString(16).padStart(2, '0')).join(' '));
    
    if (payloadData.length < 2) {
      console.log('Payload too short for WiFi data');
      return networks;
    }
    
    // 检查是否是分片帧格式还是直接的WiFi数据
    let dataStart, dataEnd;
    
    // 检查是否是分片帧格式：前5个字节是头部，第3个字节（dataLength）为0
    if (payloadData.length >= 5 && payloadData[2] === 0) {
      // 分片帧格式：[帧控制][序列号][数据长度][内容总长度(2字节)][数据内容][校验]
      console.log('📋 Fragmented frame format detected');
      dataStart = 5;
      dataEnd = payloadData.length - 2; // Skip 2-byte checksum at end
    } else {
      // 直接的WiFi数据
      console.log('📋 Direct WiFi data format detected');
      dataStart = 0;
      dataEnd = payloadData.length;
    }
    
    const actualDataLength = dataEnd - dataStart;
    console.log(`📊 Data section: offset ${dataStart}, length ${actualDataLength}`);
    console.log(`📊 Actual data (hex): ${Array.from(payloadData.slice(dataStart, dataEnd)).map(b => b.toString(16).padStart(2, '0')).join(' ')}`);
    
    if (actualDataLength <= 0) {
      console.log('No data content in frame');
      return networks;
    }
    
    // 简化的WiFi数据解析：基于实际日志分析
    // 格式：[RSSI][SSID_ASCII_DATA][RSSI][SSID_ASCII_DATA]...
    // 示例：c6 48 33 43 5f 34 30 31 07 bd 34 30 31 34
    //       -58 H3C_401     7 -67 4014
    
    let offset = dataStart;
    let networkCount = 0;
    
    console.log('🔍 Starting simplified WiFi data parsing...');
    
    while (offset < dataEnd) {
      if (offset + 1 > dataEnd) break;
      
      console.log(`\n--- WiFi Network ${networkCount + 1} ---`);
      console.log('Offset:', offset, 'Remaining:', dataEnd - offset);
      console.log('Next bytes:', Array.from(payloadData.slice(offset, Math.min(offset + 10, dataEnd))).map(b => b.toString(16).padStart(2, '0')).join(' '));
      
      // 读取RSSI
      const rssiRaw = payloadData[offset];
      const rssi = rssiRaw > 127 ? rssiRaw - 256 : rssiRaw;
      console.log('RSSI raw:', rssiRaw, '→', rssi, 'dBm');
      
      // 查找连续的ASCII字符作为SSID
      let ssidStart = offset + 1;
      let ssidLength = 0;
      let ssidEnd = ssidStart;
      
      // 从RSSI后开始查找ASCII字符
      for (let i = ssidStart; i < dataEnd; i++) {
        const char = payloadData[i];
        if (char >= 0x20 && char <= 0x7E) {
          // 可打印ASCII字符
          ssidLength++;
          ssidEnd = i + 1;
        } else {
          // 遇到非ASCII字符，检查下一个字节是否可能是RSSI
          const nextByte = payloadData[i];
          const nextRssi = nextByte > 127 ? nextByte - 256 : nextByte;
          
          // 如果下一个字节看起来像RSSI值（-100到-30之间），则停止
          if (nextRssi >= -100 && nextRssi <= -30) {
            console.log('Found potential next RSSI at offset', i, 'value:', nextRssi);
            break;
          }
          
          // 否则继续查找
          ssidLength++;
          ssidEnd = i + 1;
        }
      }
      
      if (ssidLength > 0) {
        const ssidBytes = payloadData.slice(ssidStart, ssidEnd);
        const ssid = new TextDecoder('utf-8').decode(ssidBytes);
        
        console.log('Found SSID:', `"${ssid}"`, '(length:', ssidLength, ')');
        
        // 创建WiFi网络对象
        const network = {
          id: `wifi_${Date.now()}_${networkCount}`,
          name: ssid,
          security: 'Unknown',
          strength: rssi,
          frequency: 0,
          channel: 0
        };
        
        networks.push(network);
        networkCount++;
        console.log(`✅ Successfully parsed WiFi network ${networkCount}: "${ssid}" (${rssi} dBm)`);
        
        // 更新偏移量到SSID结束位置
        offset = ssidEnd;
      } else {
        console.log('No valid SSID found, skipping to next byte');
        offset++;
      }
      
      // 防止无限循环
      if (offset >= dataEnd) {
        break;
      }
    }
    
    console.log(`📊 Parsed ${networkCount} WiFi networks from direct data`);
    return networks;
    
  } catch (error) {
    console.error('Failed to parse WiFi networks from payload:', error);
    return networks;
  }
}

// 测试数据：c6 48 33 43 5f 34 30 31 07 bd 34 30 31 34
const testData = new Uint8Array([
  0xc6, 0x48, 0x33, 0x43, 0x5f, 0x34, 0x30, 0x31, 
  0x07, 0xbd, 0x34, 0x30, 0x31, 0x34
]);

console.log('=== 测试WiFi解析功能 ===');
const result = parseWiFiNetworksFromPayload(testData);
console.log('\n=== 解析结果 ===');
console.log('找到的网络数量:', result.length);
result.forEach((network, index) => {
  console.log(`网络 ${index + 1}: "${network.name}" (RSSI: ${network.strength} dBm)`);
});
