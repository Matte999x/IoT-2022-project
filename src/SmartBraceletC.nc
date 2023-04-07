#include "SmartBracelet.h"
#include "Timer.h"


module SmartBraceletC {

	uses {
		interface Boot;
		interface Receive;
		interface AMSend;
		interface Timer<TMilli> as MilliTimer;
		interface SplitControl as AMControl;
		interface PacketAcknowledgements;
		interface Packet;
		interface Read<uint16_t> as ReadStatus; // status sensor
		interface Read<uint16_t> as ReadPositionX; // X position sensor
		interface Read<uint16_t> as ReadPositionY; // Y position sensor
	}


} implementation {

	// variables for the communication
	message_t packet;
	bool locked = FALSE;
	bool pairingPhase = TRUE;
	uint16_t pairedDeviceAddress;
	
	// state variable
	uint8_t status = 0;
	uint16_t positionX = 0;
	uint16_t positionY = 0;
	bool statusReady = FALSE;
	bool positionXReady = FALSE;
	bool positionYReady = FALSE;
	
	bool isThisNodeParent() {
		// nodes with odd id are parents
		return TOS_NODE_ID % 2 == 1;
	}
	
	bool isThisNodeChild() {
		// nodes with even id are children
		return !isThisNodeParent();
	}
	
	// Returns the node key starting from the node id (parents and child share the same key)
	const char* getKey() {
		// during simulation, parent and child are assumed to be instantiated with consecutive ids (odd for parent and even for child)
		return KEY[(TOS_NODE_ID + 1) / 2];
	}
	
	// Broadcasts a paring request message
	void broadcastPairingMessage();
	
	// Sends the pairing confirmation message
	void sendPairedMessage();
	
	// Ends the pairing phase and start the operation mode
	void endPairingPhase();
	
	// Reads the status and the position from the sensors
	void prepareStatusMessage();
	
	// Sends the status message to the parent
	void sendStatusMessage();
	
	// Displays status and position of the child
	void displayStatus();
	
	// Shows the missing alarm
	void missing();	

	// Application booted event
	event void Boot.booted() {
		dbg("boot","Application booted.\n");
		call AMControl.start();
	}
  
	// Radio started event
	event void AMControl.startDone(error_t err){
		if (err == SUCCESS) {
			dbg("radio", "Radio started.\n");
			call MilliTimer.startPeriodic(TIMER_PAIRING_PERIOD_MS);
		} else
			call AMControl.start();
	}
  
	// Radio stopped event
	event void AMControl.stopDone(error_t err){
		dbg("radio", "Radio stopped.\n");
	}
  
	// Timer fired event
	event void MilliTimer.fired() {
		if (pairingPhase)
			broadcastPairingMessage();
		else if (isThisNodeChild())
			prepareStatusMessage();
		else if (isThisNodeParent())
			missing();
	}
	
	// Send done event
	event void AMSend.sendDone(message_t* bufPtr, error_t err) {
		locked = FALSE;
		if (err != SUCCESS)
			dbg("radio", "Sending FAILED.\n");
	}
	
	// Message received event
	event message_t* Receive.receive(message_t* bufPtr, void* payload, uint8_t len) {
		// Check the dimensions of the message
		if (len != sizeof(msg_t))
			dbg("radio", "Received packet with unexpected length.\n");
		else {
			msg_t* rcm = (msg_t*)payload;
			// Check if the keys matches
			if (strcmp((char*)(rcm->key), getKey()) != 0) {
				dbg("radio", "Discarding packed with wrong key.\n");
			} else {
				// check the type of the message and act consequently
				if (pairingPhase && rcm->msg_type == PAIRING) {
					dbg("radio", "Pairing packet received with same key.\n");
					// accept pairing request
					pairedDeviceAddress = rcm->sourceAddress;
					sendPairedMessage();
					endPairingPhase();
				} else if (pairingPhase && rcm->msg_type == PAIRED) {
					// get notified of pairing completion
					pairedDeviceAddress = rcm->sourceAddress;
					endPairingPhase();
				} else if (!pairingPhase && isThisNodeParent() && rcm->msg_type == INFO) {
					dbg("radio", "Status packet received (STATUS = %d, X = %d, Y = %d).\n", rcm->status, rcm->positionX, rcm->positionY);
					// receive status from child
					call MilliTimer.stop();
					call MilliTimer.startPeriodic(TIMER_MISSING_TIME_MS);
					status = rcm->status;
					positionX = rcm->positionX;
					positionY = rcm->positionY;
					statusReady = TRUE;
					positionXReady = TRUE;
					positionYReady = TRUE;
					displayStatus();
				}
			}
		}
		return bufPtr;
	}
  
	// Read of the status from sensor completed event
	event void ReadStatus.readDone(error_t result, uint16_t data) {
		// P(standing) = 0.3
		// P(walking) = 0.3
		// P(running) = 0.3
		// P(falling) = 0.1
		if (data % 10 < 3)
			status = STANDING;
		else if (data % 10 < 6)
			status = WALKING;
		else if (data % 10 < 9)
			status = RUNNING;
		else
			status = FALLING;		
		statusReady = TRUE;
		// send the status message if also the X and Y position have been read from the sensors
		if (positionXReady && positionYReady)
			sendStatusMessage();
	}
  
	// Read of the position from sensor completed event
	event void ReadPositionX.readDone(error_t result, uint16_t data) {
		// This event is triggered when the fake sensor finishes to read (after a Read.read())
		positionX = data;
		positionXReady = TRUE;
		// send the status message if also the status and the Y position have been read from the sensors
		if (statusReady && positionYReady)
			sendStatusMessage();
	}
	
	// Read of the position from sensor completed event
	event void ReadPositionY.readDone(error_t result, uint16_t data) {
		// This event is triggered when the fake sensor finishes to read (after a Read.read())
		positionY = data;
		positionYReady = TRUE;
		// send the status message if also the status and the X position have been read from the sensors
		if (statusReady && positionXReady)
			sendStatusMessage();
	}
	
	void broadcastPairingMessage() {
		if (locked == FALSE) {
			// prepare the message
			msg_t* rcm = (msg_t*)call Packet.getPayload(&packet, sizeof(msg_t));
			if (rcm != NULL) {
				rcm->msg_type = PAIRING;
				strcpy((char*)(rcm->key), getKey());
				rcm->sourceAddress = TOS_NODE_ID;
				// broadcast the pairing message
				if (call AMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(msg_t)) == SUCCESS) {
					dbg("radio", "Pairing packet sent.\n");
					locked = TRUE;
				} else
					dbg("radio", "FAILED to send pairing packet.\n");
			}
		}
	}
	
	void sendPairedMessage() {
		if (locked == FALSE) {
			// prepare the message
			msg_t* rcm = (msg_t*)call Packet.getPayload(&packet, sizeof(msg_t));
			if (rcm != NULL) {
				rcm->msg_type = PAIRED;
				rcm->sourceAddress = TOS_NODE_ID;
				// send the message
				if (call AMSend.send(pairedDeviceAddress, &packet, sizeof(msg_t)) == SUCCESS) {
					dbg("radio", "Paired packet sent.\n");	
					locked = TRUE;
				} else
					dbg("radio", "FAILED to send paired packet.\n");
			}
		}
	}
	
	void endPairingPhase() {
		dbg("display", "Paired with node %d.\n", pairedDeviceAddress);
		pairingPhase = FALSE;
		call MilliTimer.stop();
		if (isThisNodeChild())
			// start timer for periodically sending the state
			call MilliTimer.startPeriodic(TIMER_PERIOD_MS);
		else
			// start timer for the missing alarm
			call MilliTimer.startPeriodic(TIMER_MISSING_TIME_MS);
	}
  
	void prepareStatusMessage() {
		call ReadStatus.read();
		call ReadPositionX.read();
		call ReadPositionY.read();
	}

	void sendStatusMessage() {
		if (locked == FALSE) {
			// prepare the message
			msg_t* rcm = (msg_t*)call Packet.getPayload(&packet, sizeof(msg_t));
			if (rcm != NULL) {
				rcm->msg_type = INFO;
				rcm->status = status;
				rcm->positionX = positionX;
				rcm->positionY = positionY;
				// send the message
				if (call AMSend.send(pairedDeviceAddress, &packet, sizeof(msg_t)) == SUCCESS) {
					dbg("radio", "Status packet sent with position (%d, %d).\n", positionX, positionY);	
					locked = TRUE;
				} else
					dbg("radio", "FAILED to send status packet.\n");
			}
		}
		statusReady = FALSE;
		positionXReady = FALSE;
		positionXReady = FALSE;
	}
	
	void displayStatus() {
		switch (status) {
			case STANDING:
				dbg("display","STANDING (%d, %d).\n", positionX, positionY);
				break;
			case WALKING:
				dbg("display","WALKING (%d, %d).\n", positionX, positionY);
				break;
			case RUNNING:
				dbg("display","RUNNING (%d, %d).\n", positionX, positionY);
				break;
			case FALLING:
				dbg("display","FALLING (%d, %d).\n", positionX, positionY);
				dbg("alarm","FALL ALARM (%d, %d).\n", positionX, positionY);
				break;
		}
	}
	
	void missing() {
		if (statusReady && positionXReady && positionYReady) {
			dbg("display","MISSING, last position = (%d, %d).\n", positionX, positionY);
			dbg("alarm","MISSING ALARM, last position = (%d, %d).\n", positionX, positionY);
		} else {
			dbg("display","MISSING, no position received.\n");
			dbg("alarm","MISSING ALARM, no position received.\n");
		}
	}

}
