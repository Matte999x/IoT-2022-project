#ifndef SMARTBRACELET_H
#define SMARTBRACELET_H


// message type
#define PAIRING 0
#define PAIRED 1
#define INFO 2

// kinematic status of the child
#define STANDING 0
#define WALKING 1
#define RUNNING 2
#define FALLING 3

// app timer periods
#define TIMER_PAIRING_PERIOD_MS 3000
#define TIMER_PERIOD_MS 10000
#define TIMER_MISSING_TIME_MS 60000

// message structure
typedef nx_struct msg {
	nx_uint8_t msg_type;
	nx_uint8_t key[20];
	nx_uint16_t sourceAddress;
	nx_uint8_t status;
	nx_uint16_t positionX;
	nx_uint16_t positionY;
} msg_t;

enum  {
	AM_MSG = 6
};

// pre-loaded random keys
static const char* KEY[20] = {
	"Pq2HBeFTEsW3Swc7g9f8",
	"bE27Yhc6Fnf3TNQKPpRG",
	"czqd5MXutw4hVSsUx9v2",
	"Fm8VEnWUM7psycP5Zwa2",
	"wTLCcRzq79hmfJnN5KZd",
	"LkGfQXz7qJm4WrKHCRN3",
	"Ch4pYWNXwEBvZua8SJcA",
	"kEnpqbsCX763gYPZmFft",
	"rHWES4NdwUkvXztDBRCa",
	"cyb3rKnszxfg8F5v9EdS",
	"HNbPgDx9TjMG3UuF5Cyw",
	"PcwZxhN7D46mseRQYMfr",
	"Duc8JPsY2G4jU73apLzQ",
	"pMzj72Je8qDuWbKBF9SZ",
	"XEM7rmRb4ZvnkP5fYVJa",
	"Ndkt7XFhPcKRz8pYq2Au",
	"rENxZYL8FphnMGwVfDK2",
	"NRr6ZsyFpcw4vSbnEkmz",
	"dH9cSNjQWkqJzrfgDsxT",
	"2Mp7FcndEX8TW5juSZrf"
};


#endif
