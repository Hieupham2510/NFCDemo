//
//  ContentView.swift
//  NFCDemo
//
//  Created by Pham Trung Hieu on 15/05/2024.
//

import SwiftUI
import CoreNFC

class NFCManager: NSObject, NFCNDEFReaderSessionDelegate {
    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: any Error) {
        print("")
    }
    
    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        print("")
    }
    
    var nfcSession: NFCNDEFReaderSession?
    
    func beginScanning() {
        guard NFCNDEFReaderSession.readingAvailable else {
            print("NFC is not available on this device")
            return
        }
        
        nfcSession = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
        nfcSession?.alertMessage = "Hold your iPhone near the NFC tag."
        nfcSession?.begin()
    }
    
    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        guard let tag = tags.first else {
            session.invalidate(errorMessage: "No tags found.")
            return
        }
        
        session.connect(to: tag) { error in
            if let error = error {
                session.invalidate(errorMessage: "Connection error: \(error.localizedDescription)")
                return
            }
            
            if let iso7816Tag = tag as? NFCISO7816Tag {
                // Gửi các lệnh APDU phù hợp để đọc dữ liệu từ thẻ
                // Bạn cần tham khảo tài liệu và chuẩn của thẻ để biết các lệnh APDU cần gửi
                
                // Ví dụ: Đọc dữ liệu từ một ứng dụng chứng minh nhân dân (eID) sử dụng lệnh APDU
                let apduCommand: [UInt8] = [
                    // Thay thế các giá trị này bằng các giá trị APDU cụ thể bạn cần gửi
                    // Class, INS, P1, P2, Length
                    0x00, 0xCA, 0x11, 0x00, 0x00
                ]
                
                let apdu = NFCISO7816APDU(data: Data(apduCommand))
                iso7816Tag.sendCommand(apdu: apdu!) { (response: Data, sw1: UInt8, sw2: UInt8, error: Swift.Error?) in
                    if let error = error {
                        session.invalidate(errorMessage: "Error sending APDU: \(error.localizedDescription)")
                        return
                    }
                    
                    // Xử lý và trích xuất thông tin từ phản hồi
                    let responseDataString = response.map { String(format: "%02x", $0) }.joined(separator: " ")
                    print("Response data: \(responseDataString)")
                }
            } else {
                session.invalidate(errorMessage: "Invalid tag type.")
            }
        }
        
        func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Swift.Error) {
            // Xử lý khi phiên NFC bị huỷ
            print("Session invalidated: \(error.localizedDescription)")
        }
        
    }
}

struct ContentView: View {
    let nfcReader = NFCReader()
    
    var body: some View {
        VStack {
            Text(nfcReader.message)
                .padding()
            Button(action: {
                nfcReader.beginScanning()
            }) {
                Text("Scan NFC Tag")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding()
    }
}


#Preview {
    ContentView()
}
