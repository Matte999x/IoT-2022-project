print "********************************************";
print "*                                          *";
print "*             TOSSIM Script                *";
print "*                                          *";
print "********************************************\n";

import sys
import time
import os

from TOSSIM import *


t = Tossim([])

# List of nodes
nodes = [1, 2]

# Noise model file
modelfile = "meyer-heavy.txt"

# Simulation output
logdir = "../logs/"
if not os.path.exists(logdir):
    os.makedirs(logdir)
out = open(logdir + "simulation_log_out_of_range.txt", "w")

# Initialization
print "Initializing mac...."
mac = t.mac()
print "Initializing radio channels (using noise file: ", modelfile, ") ..."
radio = t.radio()
print "Initializing simulator...."
t.init()

# Add debug channels
print "Activate debug message on channel boot"
t.addChannel("boot",out)
print "Activate debug message on channel radio"
t.addChannel("radio",out)
print "Activate debug message on channel display"
t.addChannel("display",out)
print "Activate debug message on channel alarm"
t.addChannel("alarm",out)

# Print the couples of nodes
couples = []
for i in sorted(set(nodes)):
	if i % 2 == 1:
		couples.append([i])
	elif len(couples) > 0 and i == couples[-1][0] + 1:
		couples[-1].append(i)
	else:
		couples.append([i])
print "Creating the following couples of nodes: "
for i in couples:
	print " ", i

# Create the nodes
for i in nodes:
	t.getNode(i).bootAtTime(0)

# Create the radio channels
print "Creating radio channels (all nodes in range of each other) ..."
for i in nodes:
	for j in nodes:
		if i != j:
			radio.add(i, j, -60.0)

# Create the channel model
print "Initializing Closest Pattern Matching (CPM)..."
noise = open(modelfile, "r")
lines = noise.readlines()
print "Reading noise model data file:", modelfile
for line in lines:
    str = line.strip()
    if (str != ""):
        val = int(str)
        for i in nodes:
            t.getNode(i).addNoiseTraceReading(val)
for i in nodes:
    print "Creating noise model for node:",i
    t.getNode(i).createNoiseModel()

# Simulation
print ">>> Start simulation with TOSSIM!\n";
for i in range(0,2500):
	t.runNextEvent()

# Turn off child mote
print "Turning off mote 2 ..."
t.getNode(2).turnOff()

for i in range(0,2500):
	t.runNextEvent()	
print "\nSimulation finished!"

