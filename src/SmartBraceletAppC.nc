#include "SmartBracelet.h"


configuration SmartBraceletAppC {}

implementation {

	components MainC, SmartBraceletC as App;
	components new AMSenderC(AM_MSG);
	components new AMReceiverC(AM_MSG);
	components new TimerMilliC();
	components ActiveMessageC;
	components new FakeSensorC() as StatusSensor;
	components new FakeSensorC() as PositionSensorX;
	components new FakeSensorC() as PositionSensorY;
  
	//Boot interface
	App.Boot -> MainC.Boot;

	//Send and Receive interfaces
	App.Receive -> AMReceiverC;
	App.AMSend -> AMSenderC;

	//Radio Control
	App.AMControl -> ActiveMessageC;

	//Radio Control
	App.PacketAcknowledgements -> ActiveMessageC;  

	//Interfaces to access package fields
	App.Packet -> AMSenderC;

	//Timer interface
	App.MilliTimer -> TimerMilliC;

	//Fake Sensor read
	App.ReadStatus -> StatusSensor.Read;
	App.ReadPositionX -> PositionSensorX.Read;
	App.ReadPositionY -> PositionSensorY.Read;
  
}
