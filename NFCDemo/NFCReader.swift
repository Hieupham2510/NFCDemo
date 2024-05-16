import CoreNFC

class NFCReader: NSObject, ObservableObject, NFCTagReaderSessionDelegate {
    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
        print("session", session)
    }
    
    @Published var message: String = "Scan an NFC tag"
    var session: NFCTagReaderSession?

    func beginScanning() {
        guard NFCTagReaderSession.readingAvailable else {
            message = "NFC is not available on this device"
            return
        }

        session = NFCTagReaderSession(pollingOption: .iso14443, delegate: self)
        session?.alertMessage = "Hold your NFC tag near the device."
        session?.begin()
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        DispatchQueue.main.async {
            self.message = "NFC session invalidated: \(error.localizedDescription)"
        }
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard let firstTag = tags.first else {
            session.invalidate(errorMessage: "No tags found.")
            return
        }

        session.connect(to: firstTag) { (error: Error?) in
            if let error = error {
                DispatchQueue.main.async {
                    self.message = "Failed to connect to tag: \(error.localizedDescription)"
                }
                session.invalidate(errorMessage: "Connection failed.")
                return
            }

            if case let .iso7816(tag) = firstTag {
                // AID for VISA
                let aidVisa = Data([0xA0, 0x00, 0x00, 0x00, 0x03, 0x10, 0x10])

               // let aidVisa = Data([0xA0, 0x00])
                let selectCommand = NFCISO7816APDU(instructionClass: 0x00, instructionCode: 0xA4, p1Parameter: 0x04, p2Parameter: 0x00, data: aidVisa, expectedResponseLength: -1)
                
                tag.sendCommand(apdu: selectCommand) { (response: Data, sw1: UInt8, sw2: UInt8, error: Error?) in
                    if let error = error {
                        DispatchQueue.main.async {
                            self.message = "Error sending SELECT AID APDU: \(error.localizedDescription)"
                        }
                        session.invalidate(errorMessage: "SELECT AID command failed.")
                        return
                    }

                    if sw1 == 0x90 && sw2 == 0x00 {
                        DispatchQueue.main.async {
                            self.message = "SELECT AID Response: \(response.hexEncodedString())"
                        }
                        
                        // Read records
                        self.readRecords(from: tag, session: session)
                    } else {
                        DispatchQueue.main.async {
                            self.message = "Failed to select AID: SW1: \(sw1), SW2: \(sw2)"
                        }
                        session.invalidate(errorMessage: "Failed to select AID.")
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.message = "Not a compatible ISO7816 tag"
                }
                session.invalidate(errorMessage: "Tag not compatible.")
            }
        }
    }

    func readRecords(from tag: NFCISO7816Tag, session: NFCTagReaderSession) {
        for sfi in 1...31 {
            for record in 1...16 {
                let readCommand = NFCISO7816APDU(instructionClass: 0x00, instructionCode: 0xB2, p1Parameter: UInt8(record), p2Parameter: UInt8((sfi << 3) | 4), data: Data(), expectedResponseLength: 0x00)
                
                tag.sendCommand(apdu: readCommand) { (response: Data, sw1: UInt8, sw2: UInt8, error: Error?) in
                    if let error = error {
                        DispatchQueue.main.async {
                            self.message = "Error reading record SFI \(sfi) Record \(record): \(error.localizedDescription)"
                        }
                        session.invalidate(errorMessage: "Read record command failed.")
                        return
                    }

                    if sw1 == 0x90 && sw2 == 0x00 {
                        DispatchQueue.main.async {
                            self.message = "SFI \(sfi) Record \(record): \(response.hexEncodedString())"
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.message = "SFI \(sfi) Record \(record) not found."
                        }
                    }
                }
            }
        }
        session.invalidate()
    }
}

extension Data {
    func hexEncodedString() -> String {
        return map { String(format: "%02hhx", $0) }.joined()
    }
}
