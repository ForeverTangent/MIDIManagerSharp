//
//  MIDIManager.swift
//  AKExtensionsAUHostV4
//
//  Created by Stanley Rosenbaum on 2/13/20.
//  Copyright © 2020 STAQUE. All rights reserved.
//  Orginal by Gene de Lisa.
//  https://github.com/genedelisa/SwiftMIDI

import Foundation
import CoreMIDI
import CoreAudio
import AudioToolbox

import AVFoundation
import os


protocol MIDIManagerDelegate {
	func scheduleAMIDINote(on: Bool, noteNumber: UInt8, at velocity: UInt8)
	func scheduleACCFor(_ cc: UInt8, with data: UInt8)
	func scheduleAPitchBendWith(lsb: UInt8, msb: UInt8)
}


/// The `Singleton` instance
@available(iOS 10.0, *)
class MIDIManager {

	// MARK: - Propeties

	static let shared = MIDIManager()
	static let subsystem = "MIDIManager"
	static let category = "MIDI"
	static let midiLog = OSLog(subsystem: subsystem, category: category)

	var midiClient = MIDIClientRef()

	var outputPort = MIDIPortRef()

	var inputPort = MIDIPortRef()

	var virtualSourceEndpointRef = MIDIEndpointRef()

	var virtualDestinationEndpointRef = MIDIEndpointRef()

	var midiInputPortRef = MIDIPortRef()

	var processingGraph:AUGraph?

	var midiManagerDelegate: MIDIManagerDelegate?

	// MARK: - Inits

	init() {
		// initializer code here
	}

	// MARK: - Class Methods

	func deInitMIDI() {
		removeNotifications()
		disableNetwork()
		os_log("DE-initializing MIDI", log: MIDIManager.midiLog, type: .debug)
	}

	func initMIDI(midiNotifier: MIDINotifyBlock? = nil, reader: MIDIReadBlock? = nil) {

		os_log("Initializing MIDI", log: MIDIManager.midiLog, type: .debug)

		observeNotifications()

		enableNetwork()


		var notifyBlock: MIDINotifyBlock

		if midiNotifier != nil {
			notifyBlock = midiNotifier!
		} else {
			notifyBlock = MyMIDINotifyBlock
		}

		var readBlock: MIDIReadBlock
		if reader != nil {
			readBlock = reader!
		} else {
			readBlock = MyMIDIReadBlock
		}

		var status = noErr
		status = MIDIClientCreateWithBlock("MIDIManager.MyMIDIClient" as CFString, &midiClient, notifyBlock)

		if status == noErr {
			os_log("Created MIDI client %d", log: MIDIManager.midiLog, type: .debug, midiClient)
		} else {
			os_log("Error creating MIDI client %@", log: MIDIManager.midiLog, type: .error, status)
			checkError(status)
		}


		if status == noErr {

			status = MIDIInputPortCreateWithBlock(midiClient, "MIDIManager.MIDIInputPort" as CFString, &inputPort, readBlock)
			if status == noErr {
				os_log("Created input port %d", log: MIDIManager.midiLog, type: .debug, inputPort)
			} else {
				os_log("Error creating input port %@", log: MIDIManager.midiLog, type: .error, status)
				checkError(status)
			}


			status = MIDIOutputPortCreate(midiClient,
										  "AUv3Host" as CFString,
										  &outputPort)

			if status == noErr {
				os_log("Created output port %d", log: MIDIManager.midiLog, type: .debug, outputPort)
			} else {
				os_log("Error creating output port %@", log: MIDIManager.midiLog, type: .error, status)
				checkError(status)
			}


			// this is the sequence's destination. Remember to set background mode in info.plist
			status = MIDIDestinationCreateWithBlock(midiClient,
													"SwiftMIDI.VirtualDestination" as CFString,
													&virtualDestinationEndpointRef,
													MIDIPassThru)
			//                                                    readBlock)

			if status == noErr {
				os_log("Created virtual destination %d", log: MIDIManager.midiLog, type: .debug, virtualDestinationEndpointRef)
			} else {
				os_log("Error creating virtual destination %@", log: MIDIManager.midiLog, type: .error, status)
				checkError(status)
			}

			//use MIDIReceived to transmit MIDI messages from your virtual source to any clients connected to the virtual source
			status = MIDISourceCreate(midiClient,
									  "SwiftMIDI.VirtualSource" as CFString,
									  &virtualSourceEndpointRef
			)

			if status == noErr {
				os_log("created virtual source %d", log: MIDIManager.midiLog, type: .debug, virtualSourceEndpointRef)
			} else {
				os_log("Error creating virtual source %@", log: MIDIManager.midiLog, type: .error, status)
				checkError(status)
			}


			connectSourcesToInputPort()

			// let's see some device info for fun
			//			// print("All Devices:")
			//			allDeviceProps()

			//			// print("All External Devices:")
			//			allExternalDeviceProps()

			//			// print("All Destinations:")
			//			allDestinationProps()

			//			// print("All Sources:")
			//			allSourceProps()
		}

	}

	func observeNotifications() {
		//		NotificationCenter.default.addObserver(self,
		//											   selector: #selector(midiNetworkChanged(notification:)),
		//											   name:NSNotification.Name(rawValue: MIDINetworkNotificationSessionDidChange),
		//											   object: nil)
		//		NotificationCenter.default.addObserver(self,
		//											   selector: #selector(midiNetworkContactsChanged(notification:)),
		//											   name:NSNotification.Name(rawValue: MIDINetworkNotificationContactsDidChange),
		//											   object: nil)
	}


	func removeNotifications() {
		//		NotificationCenter.default.removeObserver(self,
		//												  name: NSNotification.Name(rawValue: MIDINetworkNotificationSessionDidChange),
		//												  object: nil)
		//
		//		NotificationCenter.default.removeObserver(self,
		//												  name: NSNotification.Name(rawValue: MIDINetworkNotificationContactsDidChange),
		//												  object: nil)
	}


	// signifies that other aspects of the session changed, such as the connection list, connection policy
	@objc func midiNetworkChanged(notification:NSNotification) {
		//		print("\(#function)")
		//		print("\(notification)")
		//		if let session = notification.object as? MIDINetworkSession {
		//			print("session \(session)")
		//			for connection in session.connections() {
		//				print("connection \(connection)")
		//			}
		//			print("isEnabled \(session.isEnabled)")
		//			print("sourceEndpoint \(session.sourceEndpoint())")
		//			print("destinationEndpoint \(session.destinationEndpoint())")
		//			print("networkName \(session.networkName)")
		//			print("localName \(session.localName)")
		//
		//			if let deviceName = getDeviceName(session.sourceEndpoint()) {
		//				print("source name \(deviceName)")
		//			}
		//
		//			if let deviceName = getDeviceName(session.destinationEndpoint()) {
		//				print("destination name \(deviceName)")
		//			}
		//		}
	}

	@objc func midiNetworkContactsChanged(notification:NSNotification) {
		//		print("\(#function)")
		//		print("\(notification)")
		//		if let session = notification.object as? MIDINetworkSession {
		//			print("session \(session)")
		//			for contact in session.contacts() {
		//				 print("contact \(contact)")
		//			}
		//		}
	}


	func showMIDIObjectType(_ ot: MIDIObjectType) {
		switch ot {
			case .other:
				os_log("midiObjectType: Other", log: MIDIManager.midiLog, type: .debug)
				break

			case .device:
				os_log("midiObjectType: Device", log: MIDIManager.midiLog, type: .debug)
				break

			case .entity:
				os_log("midiObjectType: Entity", log: MIDIManager.midiLog, type: .debug)
				break

			case .source:
				os_log("midiObjectType: Source", log: MIDIManager.midiLog, type: .debug)
				break

			case .destination:
				os_log("midiObjectType: Destination", log: MIDIManager.midiLog, type: .debug)
				break

			case .externalDevice:
				os_log("midiObjectType: ExternalDevice", log: MIDIManager.midiLog, type: .debug)
				break

			case .externalEntity:
				// print("midiObjectType: ExternalEntity")
				os_log("midiObjectType: ExternalEntity", log: MIDIManager.midiLog, type: .debug)
				break

			case .externalSource:
				os_log("midiObjectType: ExternalSource", log: MIDIManager.midiLog, type: .debug)
				break

			case .externalDestination:
				os_log("midiObjectType: ExternalDestination", log: MIDIManager.midiLog, type: .debug)
				break
			@unknown default:
				fatalError("Fatal Error: ExternalDestination")
		}

	}


	func handleMIDI(_ packet:MIDIPacket) {

		let status = packet.data.0
		let d1 = packet.data.1
		let d2 = packet.data.2
		let rawStatus = status & 0xF0 // without channel
		let channel = status & 0x0F

		switch rawStatus {

			case 0x80:
				// print("Note off. Channel \(channel) note \(d1) velocity \(d2)")
				// forward to sampler
				playNoteOff(UInt32(channel), noteNum: UInt32(d1))

			case 0x90:
				// print("Note on. Channel \(channel) note \(d1) velocity \(d2)")
				// forward to sampler
				playNoteOn(UInt32(channel), noteNum:UInt32(d1), velocity: UInt32(d2))

			case 0xA0:
				// print("Polyphonic Key Pressure (Aftertouch). Channel \(channel) note \(d1) pressure \(d2)")
				break
			case 0xB0:
				// print("Control Change. Channel \(channel) controller \(d1) value \(d2)")
				performCCOn(UInt32(channel), cc:UInt32(d1), cc_value: UInt32(d2))

			case 0xC0:
				// print("Program Change. Channel \(channel) program \(d1)")
				break
			case 0xD0:
				// print("Channel Pressure (Aftertouch). Channel \(channel) pressure \(d1)")
				break
			case 0xE0:
				// print("Pitch Bend Change. Channel \(channel) lsb \(d1) msb \(d2)")
				performPitchBendOn(UInt32(channel), withLSB: UInt32(d1), andMSB: UInt32(d2))

			default:
				print("Unhandled message \(status)")
				break
		}
	}



	//typealias MIDINotifyBlock = (UnsafePointer<MIDINotification>) -> Void
	func MyMIDINotifyBlock(midiNotification: UnsafePointer<MIDINotification>) {
		// print("\ngot a MIDINotification!")

		let notification = midiNotification.pointee
		// print("MIDI Notify, messageId= \(notification.messageID)")
		// print("MIDI Notify, messageSize= \(notification.messageSize)")

		switch notification.messageID {

			// Some aspect of the current MIDISetup has changed.  No data.  Should ignore this  message if messages 2-6 are handled.
			case .msgSetupChanged:
				// print("MIDI setup changed")
				//				let ptr = UnsafeMutablePointer<MIDINotification>(mutating: midiNotification)
				//				let m = ptr.pointee
				//				print(m)
				//				print("id \(m.messageID)")
				//				print("size \(m.messageSize)")
				break


			// A device, entity or endpoint was added. Structure is MIDIObjectAddRemoveNotification.
			case .msgObjectAdded:

				// print("added")
				//            let ptr = UnsafeMutablePointer<MIDIObjectAddRemoveNotification>(midiNotification)

				midiNotification.withMemoryRebound(to: MIDIObjectAddRemoveNotification.self, capacity: 1) {
					let m = $0.pointee
					// print(m)
					// print("id \(m.messageID)")
					// print("size \(m.messageSize)")
					// print("child \(m.child)")
					// print("child type \(m.childType)")
					showMIDIObjectType(m.childType)
					// print("parent \(m.parent)")
					// print("parentType \(m.parentType)")
					showMIDIObjectType(m.parentType)
					// print("childName \(String(describing: getDeviceName(m.child)))")
				}


				break

			// A device, entity or endpoint was removed. Structure is MIDIObjectAddRemoveNotification.
			case .msgObjectRemoved:
				// print("kMIDIMsgObjectRemoved")

				midiNotification.withMemoryRebound(to: MIDIObjectAddRemoveNotification.self, capacity: 1) {
					let m = $0.pointee
					print(m)
					//					print("id \(m.messageID)")
					//					print("size \(m.messageSize)")
					//					print("child \(m.child)")
					//					print("child type \(m.childType)")
					//					print("parent \(m.parent)")
					//					print("parentType \(m.parentType)")
					//
					//					print("childName \(String(describing: getDeviceName(m.child)))")
				}
				break

			// An object's property was changed. Structure is MIDIObjectPropertyChangeNotification.
			case .msgPropertyChanged:
				// print("kMIDIMsgPropertyChanged")

				midiNotification.withMemoryRebound(to: MIDIObjectPropertyChangeNotification.self, capacity: 1) {

					let m = $0.pointee
					print(m)
					// print("id \(m.messageID)")
					// print("size \(m.messageSize)")
					// print("object \(m.object)")
					// print("objectType  \(m.objectType)")
					// print("propertyName  \(m.propertyName)")
					// print("propertyName  \(m.propertyName.takeUnretainedValue())")

					if m.propertyName.takeUnretainedValue() as String == "apple.midirtp.session" {
						// print("connected")
					}
				}

				break

			//  A persistent MIDI Thru connection wasor destroyed.  No data.
			case .msgThruConnectionsChanged:
				// print("MIDI thru connections changed.")
				break

			//  A persistent MIDI Thru connection was created or destroyed.  No data.
			case .msgSerialPortOwnerChanged:
				// print("MIDI serial port owner changed.")
				break

			case .msgIOError:
				// print("MIDI I/O error.")

				//				midiNotification.withMemoryRebound(to: MIDIIOErrorNotification.self, capacity: 1) {
				//					let m = $0.pointee
				//					print(m)
				//					print("id \(m.messageID)")
				//					print("size \(m.messageSize)")
				//					print("driverDevice \(m.driverDevice)")
				//					print("errorCode \(m.errorCode)")
				//				}
				break
			@unknown default:
				fatalError("Fatal Error: withMemoryRebound")
		}
	}

	func MIDIPassThru(_ packetList: UnsafePointer<MIDIPacketList>, srcConnRefCon: UnsafeMutableRawPointer?) -> Swift.Void {
		MIDIReceived(virtualSourceEndpointRef, packetList)
	}



	func MyMIDIReadBlock(packetList: UnsafePointer<MIDIPacketList>, srcConnRefCon: UnsafeMutableRawPointer?) -> Swift.Void {

		let packets = packetList.pointee

		let packet:MIDIPacket = packets.packet

		var ap = UnsafeMutablePointer<MIDIPacket>.allocate(capacity: 1)
		ap.initialize(to:packet)

		for _ in 0 ..< packets.numPackets {
			let p = ap.pointee
			//			print("timestamp \(p.timeStamp)", terminator: "")
			//			var hex = String(format:"0x%X", p.data.0)
			//			print(" \(hex)", terminator: "")
			//			hex = String(format:"0x%X", p.data.1)
			//			print(" \(hex)", terminator: "")
			//			hex = String(format:"0x%X", p.data.2)
			//			print(" \(hex)")

			handleMIDI(p)

			ap = MIDIPacketNext(ap)
		}
	}

	func enableNetwork() {
		MIDINetworkSession.default().isEnabled = true
		MIDINetworkSession.default().connectionPolicy = .anyone

		// print("net session enabled \(MIDINetworkSession.default().isEnabled)")
		// print("net session networkPort \(MIDINetworkSession.default().networkPort)")
		// print("net session networkName \(MIDINetworkSession.default().networkName)")
		// print("net session localName \(MIDINetworkSession.default().localName)")

	}

	func disableNetwork() {
		MIDINetworkSession.default().connectionPolicy = .noOne
		MIDINetworkSession.default().isEnabled = false

		// print("net session enabled \(MIDINetworkSession.default().isEnabled)")
	}

	func connectSourcesToInputPort() {
		let sourceCount = MIDIGetNumberOfSources()
		// print("source count \(sourceCount)")

		for srcIndex in 0 ..< sourceCount {
			let midiEndPoint = MIDIGetSource(srcIndex)

			let status = MIDIPortConnectSource(inputPort,
											   midiEndPoint,
											   nil)

			if status == noErr {
				os_log("Connected endpoint to inputPort", log: MIDIManager.midiLog, type: .debug)
			} else {
				// print("oh crap!")
				checkError(status)
			}
		}
	}

	func disconnectSourceFromInputPort(_ sourceMidiEndPoint:MIDIEndpointRef) -> OSStatus {
		let status = MIDIPortDisconnectSource(inputPort,
											  sourceMidiEndPoint
		)
		if status == noErr {
			// print("yay disconnected endpoint \(sourceMidiEndPoint) from inputPort! \(inputPort)")
		} else {
			os_log("could not disconnect inputPort %@ endpoint %@ status %@", log: MIDIManager.midiLog, type: .error, inputPort,sourceMidiEndPoint,status )
			checkError(status)
		}
		return status
	}


	func getDeviceName(_ endpoint:MIDIEndpointRef) -> String? {
		var cfs: Unmanaged<CFString>?
		let status = MIDIObjectGetStringProperty(endpoint, kMIDIPropertyName, &cfs)
		if status != noErr {
			os_log("error getting device name for %@. status %@", log: MIDIManager.midiLog, type: .error, endpoint, status)
			checkError(status)
		}

		if let s = cfs {
			return s.takeRetainedValue() as String
		}

		return nil
	}

	func allExternalDeviceProps() {

		let n = MIDIGetNumberOfExternalDevices()
		os_log("external devices %d", log: MIDIManager.midiLog, type: .debug, n)

		for i in 0 ..< n {
			let midiDevice = MIDIGetExternalDevice(i)
			printProperties(midiDevice)
		}
	}

	func allDeviceProps() {

		let n = MIDIGetNumberOfDevices()
		os_log("number of devices %d", log: MIDIManager.midiLog, type: .debug, n)

		for i in 0 ..< n {
			let midiDevice = MIDIGetDevice(i)
			printProperties(midiDevice)
		}
	}

	func allDestinationProps() {
		let numberOfDestinations  = MIDIGetNumberOfDestinations()
		os_log("destinations %d", log: MIDIManager.midiLog, type: .debug, numberOfDestinations)

		for i in 0 ..< numberOfDestinations {
			let endpoint = MIDIGetDestination(i)
			printProperties(endpoint)
		}
	}

	func allSourceProps() {
		let numberOfSources  = MIDIGetNumberOfSources()
		os_log("numberOfSources %d", log: MIDIManager.midiLog, type: .debug, numberOfSources)

		for i in 0 ..< numberOfSources {
			let endpoint = MIDIGetSource(i)
			printProperties(endpoint)
		}
	}

	func printProperties(_ midiobject:MIDIObjectRef) {
		var unmanagedProperties: Unmanaged<CFPropertyList>?
		let status = MIDIObjectGetProperties(midiobject, &unmanagedProperties, true)
		checkError(status)

		if let midiProperties: CFPropertyList = unmanagedProperties?.takeUnretainedValue() {
			if let midiDictionary = midiProperties as? Dictionary<String, Any> {
				os_log("MIDI properties %{public}@", log: MIDIManager.midiLog, type: .debug, midiDictionary)
				for (key, value) in midiDictionary {
					// print("key '\(key)', value '\(value)'")
					// what a mess. and the public doesn't really help here.
					os_log("key %{public}@ value %{public}@", log: MIDIManager.midiLog, type: .debug, key, value as! CVarArg)
				}

			}
		} else {
			os_log("Couldn't load properties for %@", log: MIDIManager.midiLog, type: .error, midiobject)
		}
	}

	func propertyValue(_ midiobject:MIDIObjectRef, propName:String) -> String? {
		var unmanagedProperties: Unmanaged<CFPropertyList>?
		let status = MIDIObjectGetProperties(midiobject, &unmanagedProperties, true)
		checkError(status)

		if let midiProperties: CFPropertyList = unmanagedProperties?.takeUnretainedValue() {
			if let midiDictionary = midiProperties as? NSDictionary {
				os_log("MIDI properties %@", log: MIDIManager.midiLog, type: .debug, midiDictionary)
				return midiDictionary[propName] as? String
			}
		} else {
			os_log("Couldn't load properties for %@", log: MIDIManager.midiLog, type: .error, midiobject)
		}

		return nil
	}


	func playNoteOn(_ channel:UInt32, noteNum:UInt32, velocity:UInt32)    {
		//		let noteCommand = UInt32(0x90 | channel)

		midiManagerDelegate?.scheduleAMIDINote(on: true, noteNumber: UInt8(noteNum), at: UInt8(velocity))

		// print("\(noteCommand)")
	}

	func playNoteOff(_ channel:UInt32, noteNum:UInt32)    {
		//		let noteCommand = UInt32(0x80 | channel)

		midiManagerDelegate?.scheduleAMIDINote(on: false, noteNumber: UInt8(noteNum), at: 0)

		// print("\(noteCommand)")

	}

	func performCCOn(_ channel:UInt32, cc:UInt32, cc_value:UInt32)    {
		//		let midiCommand = UInt32(0xB0 | channel)

		midiManagerDelegate?.scheduleACCFor(UInt8(cc), with: UInt8(cc_value))

		// print("CC \(midiCommand) \(cc_value)")
	}

	func performPitchBendOn(_ channel:UInt32, withLSB lsb:UInt32, andMSB msb:UInt32)    {
		//		let midiCommand = UInt32(0xE0 | channel)

		midiManagerDelegate?.scheduleAPitchBendWith(lsb: UInt8(lsb), msb: UInt8(msb))
		// print("Pitchbend \(midiCommand) \(lsb) \(msb)")
	}



	///  Check the status code returned from most Core MIDI functions.
	///  Sort of like Adamson's CheckError.
	///  For other projects you can uncomment the Core MIDI constants.
	///
	///  - parameter error: an `OSStatus` returned from a Core MIDI function.
	internal func checkError(_ error:OSStatus) {
		if error == noErr {return}

		if let s = MIDIManager.stringFrom4(status:error) {
			// print("error string '\(s)'")
			os_log("error string %@", log: MIDIManager.midiLog, type: .error, s)
		}

		switch(error) {

			case kMIDIInvalidClient :
				os_log("kMIDIInvalidClient", log: MIDIManager.midiLog, type: .error)

			case kMIDIInvalidPort :
				os_log("kMIDIInvalidPort", log: MIDIManager.midiLog, type: .error)

			case kMIDIWrongEndpointType :
				os_log("kMIDIWrongEndpointType", log: MIDIManager.midiLog, type: .error)

			case kMIDINoConnection :
				os_log("kMIDINoConnection", log: MIDIManager.midiLog, type: .error)

			case kMIDIUnknownEndpoint :
				os_log("kMIDIUnknownEndpoint", log: MIDIManager.midiLog, type: .error)

			case kMIDIUnknownProperty :
				os_log("kMIDIUnknownProperty", log: MIDIManager.midiLog, type: .error)

			case kMIDIWrongPropertyType :
				os_log("kMIDIWrongPropertyType", log: MIDIManager.midiLog, type: .error)

			case kMIDINoCurrentSetup :
				os_log("kMIDINoCurrentSetup", log: MIDIManager.midiLog, type: .error)

			case kMIDIMessageSendErr :
				os_log("kMIDIMessageSendErr", log: MIDIManager.midiLog, type: .error)

			case kMIDIServerStartErr :
				os_log("kMIDIServerStartErr", log: MIDIManager.midiLog, type: .error)

			case kMIDISetupFormatErr :
				os_log("kMIDISetupFormatErr", log: MIDIManager.midiLog, type: .error)

			case kMIDIWrongThread :
				os_log("kMIDIWrongThread", log: MIDIManager.midiLog, type: .error)

			case kMIDIObjectNotFound :
				os_log("kMIDIObjectNotFound", log: MIDIManager.midiLog, type: .error)

			case kMIDIIDNotUnique :
				os_log("kMIDIIDNotUnique", log: MIDIManager.midiLog, type: .error)

			case kMIDINotPermitted :
				os_log("kMIDINotPermitted", log: MIDIManager.midiLog, type: .error)
				os_log("did you set UIBackgroundModes to audio in your info.plist?", log: MIDIManager.midiLog, type: .error)

			//AUGraph.h
			case kAUGraphErr_NodeNotFound:
				os_log("kAUGraphErr_NodeNotFound", log: MIDIManager.midiLog, type: .error)

			case kAUGraphErr_OutputNodeErr:
				os_log("kAUGraphErr_OutputNodeErr", log: MIDIManager.midiLog, type: .error)

			case kAUGraphErr_InvalidConnection:
				os_log("kAUGraphErr_InvalidConnection", log: MIDIManager.midiLog, type: .error)

			case kAUGraphErr_CannotDoInCurrentContext:
				os_log("kAUGraphErr_CannotDoInCurrentContext", log: MIDIManager.midiLog, type: .error)

			case kAUGraphErr_InvalidAudioUnit:
				os_log("kAUGraphErr_InvalidAudioUnit", log: MIDIManager.midiLog, type: .error)

			// core audio

			case kAudio_UnimplementedError:
				os_log("kAudio_UnimplementedError", log: MIDIManager.midiLog, type: .error)

			case kAudio_FileNotFoundError:
				os_log("kAudio_FileNotFoundError", log: MIDIManager.midiLog, type: .error)

			case kAudio_FilePermissionError:
				os_log("kAudio_FilePermissionError", log: MIDIManager.midiLog, type: .error)

			case kAudio_TooManyFilesOpenError:
				os_log("kAudio_TooManyFilesOpenError", log: MIDIManager.midiLog, type: .error)

			case kAudio_BadFilePathError:
				os_log("kAudio_BadFilePathError", log: MIDIManager.midiLog, type: .error)

			case kAudio_ParamError:
				os_log("kAudio_ParamError", log: MIDIManager.midiLog, type: .error)

			case kAudio_MemFullError:
				os_log("kAudio_MemFullError", log: MIDIManager.midiLog, type: .error)



			// AudioToolbox

			case kAudioToolboxErr_InvalidSequenceType :
				os_log("kAudioToolboxErr_InvalidSequenceType", log: MIDIManager.midiLog, type: .error)

			case kAudioToolboxErr_TrackIndexError :
				os_log("kAudioToolboxErr_TrackIndexError", log: MIDIManager.midiLog, type: .error)

			case kAudioToolboxErr_TrackNotFound :
				os_log("kAudioToolboxErr_TrackNotFound", log: MIDIManager.midiLog, type: .error)

			case kAudioToolboxErr_EndOfTrack :
				os_log("kAudioToolboxErr_EndOfTrack", log: MIDIManager.midiLog, type: .error)

			case kAudioToolboxErr_StartOfTrack :
				os_log("kAudioToolboxErr_StartOfTrack", log: MIDIManager.midiLog, type: .error)

			case kAudioToolboxErr_IllegalTrackDestination :
				os_log("kAudioToolboxErr_IllegalTrackDestination", log: MIDIManager.midiLog, type: .error)

			case kAudioToolboxErr_NoSequence :
				os_log("kAudioToolboxErr_NoSequence", log: MIDIManager.midiLog, type: .error)

			case kAudioToolboxErr_InvalidEventType :
				os_log("kAudioToolboxErr_InvalidEventType", log: MIDIManager.midiLog, type: .error)

			case kAudioToolboxErr_InvalidPlayerState :
				os_log("kAudioToolboxErr_InvalidPlayerState", log: MIDIManager.midiLog, type: .error)

			// AudioUnit

			case kAudioUnitErr_InvalidProperty :
				os_log("kAudioUnitErr_InvalidProperty", log: MIDIManager.midiLog, type: .error)

			case kAudioUnitErr_InvalidParameter :
				os_log("kAudioUnitErr_InvalidParameter", log: MIDIManager.midiLog, type: .error)

			case kAudioUnitErr_InvalidElement :
				os_log("kAudioUnitErr_InvalidElement", log: MIDIManager.midiLog, type: .error)

			case kAudioUnitErr_NoConnection :
				os_log("kAudioUnitErr_NoConnection", log: MIDIManager.midiLog, type: .error)

			case kAudioUnitErr_FailedInitialization :
				os_log("kAudioUnitErr_FailedInitialization", log: MIDIManager.midiLog, type: .error)

			case kAudioUnitErr_TooManyFramesToProcess :
				os_log("kAudioUnitErr_TooManyFramesToProcess", log: MIDIManager.midiLog, type: .error)

			case kAudioUnitErr_InvalidFile :
				os_log("kAudioUnitErr_InvalidFile", log: MIDIManager.midiLog, type: .error)

			case kAudioUnitErr_FormatNotSupported :
				os_log("kAudioUnitErr_FormatNotSupported", log: MIDIManager.midiLog, type: .error)

			case kAudioUnitErr_Uninitialized :
				os_log("kAudioUnitErr_Uninitialized", log: MIDIManager.midiLog, type: .error)

			case kAudioUnitErr_InvalidScope :
				os_log("kAudioUnitErr_InvalidScope", log: MIDIManager.midiLog, type: .error)

			case kAudioUnitErr_PropertyNotWritable :
				os_log("kAudioUnitErr_PropertyNotWritable", log: MIDIManager.midiLog, type: .error)

			case kAudioUnitErr_InvalidPropertyValue :
				os_log("kAudioUnitErr_InvalidPropertyValue", log: MIDIManager.midiLog, type: .error)

			case kAudioUnitErr_PropertyNotInUse :
				os_log("kAudioUnitErr_PropertyNotInUse", log: MIDIManager.midiLog, type: .error)

			case kAudioUnitErr_Initialized :
				os_log("kAudioUnitErr_Initialized", log: MIDIManager.midiLog, type: .error)

			case kAudioUnitErr_InvalidOfflineRender :
				os_log("kAudioUnitErr_InvalidOfflineRender", log: MIDIManager.midiLog, type: .error)

			case kAudioUnitErr_Unauthorized :
				os_log("kAudioUnitErr_Unauthorized", log: MIDIManager.midiLog, type: .error)

			default:
				os_log("huh?", log: MIDIManager.midiLog, type: .error)

		}
	}


	///  Create a String from an encoded 4char.
	///
	///  - parameter status: an `OSStatus` containing the encoded 4char.
	///
	///  - returns: The String representation. Might be nil.
	class func stringFrom4(status: OSStatus) -> String? {
		let n = Int(status)
		return stringFrom4(status:OSStatus(n))
	}

}
