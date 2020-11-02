# Start, stop, query, or configure TPV logging on a set of servers
# Example: wsadmin -username wsadmin -password wsadmin -lang jython -f tpvlogging.py -userprefs wsadmin -action start -server server1

def usage():
	print "usage: wsadmin -lang jython -f tpvlogging.py -action [start|stop|list|setlevel] -userprefs USER [-node NODE] [-server SERVER] [-pmilevel NEWLEVEL]"
	print "       -userprefs is required and you can just pass in the same user as -username for wsadmin, or any name otherwise"
	print "       -pmilevel is only used with -action setlevel. Valid values are none, basic, extended, all"
	sys.exit()

import sys
import com.ibm.ws.tpv.engine.UserPreferences as UserPreferences
import com.ibm.ws.tpv.engine.utils.ServerBean as ServerBean
import jarray
import javax.management as mgmt

sType = "APPLICATION_SERVER"
action = "start"
targetNode = ""
targetApplicationServer = ""
user = ""
filename = "tpv"
duration = 300000000
fileSize = 10485760
numFiles = 20
outputType = "bin" # or "xml"
bufferSize = 40
pmilevel = "extended" # only if -action setlevel
help = 0
refreshRate = 30
affectedCount = 0
verbose = 0

l = len(sys.argv)
i = 0
while i < l:
	arg = sys.argv[i]
	if arg == "-help" or arg == "-h" or arg == "-usage" or arg == "-?":
		help = 1
	if arg == "-action":
		action = sys.argv[i + 1]
	if arg == "-node":
		targetNode = sys.argv[i + 1]
	if arg == "-server":
		targetApplicationServer = sys.argv[i + 1]
	if arg == "-userprefs":
		user = sys.argv[i + 1]
	if arg == "-filename":
		filename = sys.argv[i + 1]
	if arg == "-duration":
		duration = int(sys.argv[i + 1])
	if arg == "-filesize":
		fileSize = int(sys.argv[i + 1])
	if arg == "-numfiles":
		numFiles = int(sys.argv[i + 1])
	if arg == "-buffersize":
		bufferSize = int(sys.argv[i + 1])
	if arg == "-refreshrate":
		refreshRate = int(sys.argv[i + 1])
	if arg == "-outputtype":
		outputType = sys.argv[i + 1]
	if arg == "-pmilevel":
		pmilevel = sys.argv[i + 1]
	if arg == "-verbose":
		verbose = 1
	i = i + 1

if help == 1:
	usage()
	
if len(user) == 0:
	print ""
	print "ERROR: -userprefs must be specified (see usage below)"
	print ""
	usage()

def getExceptionText(typ, value, tb):
	value = `value`
	sd = `tb.dumpStack()`
	sd = sd.replace("\\\\","/")
	i = sd.rfind("  File ")
	j = sd.rfind(", line ")
	k = sd.rfind(", in ")
	locn = ""
	if(i>0 and j>0 and k>0):
		file = sd[i+7:j]
		line = sd[j+7:k]
		func = sd[k+4:-3]
		locn = "Function="+func+"  Line="+line+"  File="+file
	return value+" "+locn

def convertToList( inlist ):
	outlist = []
	clist = None
	if (len(inlist) > 0): 
		if (inlist[0] == '[' and inlist[len(inlist) - 1] == ']'): 
			if (inlist[1] == "\"" and inlist[len(inlist)-2] == "\""):
				clist = inlist[1:len(inlist) -1].split(")\" ")
			else:
				clist = inlist[1:len(inlist) - 1].split(" ")
		else:
			clist = inlist.split(java.lang.System.getProperty("line.separator"))

	if clist != None:
		for elem in clist:
			elem = elem.rstrip();
			if (len(elem) > 0):
				if (elem[0] == "\"" and elem[len(elem) -1] != "\""):
					elem = elem+")\""
				outlist.append(elem)
	return outlist

def listNodes():
	nodes = AdminConfig.list("Node")
	nodeList = convertToList(nodes)
	return nodeList

def listServers(serverType="", nodeName=""):
	optionalParamList = []
	if (len(serverType) > 0):
		optionalParamList = ['-serverType', serverType]
	if (len(nodeName) > 0):
		node = AdminConfig.getid("/Node:" +nodeName+"/")
		optionalParamList = optionalParamList + ['-nodeName', nodeName]
	servers = AdminTask.listServers(optionalParamList)
	servers = convertToList(servers)
	newservers = []
	for aServer in servers:
		sname = aServer[0:aServer.find("(")]
		nname = aServer[aServer.find("nodes/")+6:aServer.find("servers/")-1]
		sid = AdminConfig.getid("/Node:"+nname+"/Server:"+sname)
		if (newservers.count(sid) <= 0):
			newservers.append(sid)
	return newservers

print "Action: " + action
print "User: " + user
print "Node: " + targetNode
print "Server: " + targetApplicationServer
print "File name: " + filename
print "Duration: " + str(duration)
print "File Size: " + str(fileSize)
print "Historical Files: " + str(numFiles)
print "Output type: " + outputType
print "Refresh Rate: " + str(refreshRate)

nodeList = listNodes()

for nodeObject in nodeList:

	nodeName = nodeObject.split("(")[0]

	if len(targetNode) > 0 and targetNode.lower() != nodeName.lower():
		print "Skipping node " + nodeName + " because it did not match targetNode"
		continue

	print ""
	print "Processing node: " + nodeName

	try:
		# build list of Application Servers in the Node
		serverList = listServers(sType,nodeName)
	except:
	    	typ, val, tb = sys.exc_info()
		value = `val`
		sd = `tb.dumpStack()`
		sd = sd.replace("\\\\","/")
		print "Could not process node. Probably the DMGR (which is ok to skip)? Continuing with the other nodes... " + value + " " + sd
		continue

	if verbose:
		print "Number of servers: " + str(len(serverList))

	for serverObject in serverList:
		serverName = serverObject.split("(")[0]

		if len(targetApplicationServer) > 0 and targetApplicationServer.lower() != serverName.lower():
			if verbose:
				print "Skipping server " + serverName + " (node " + nodeName + ")"
			continue

		prefs = UserPreferences()
		prefs.setServerName(serverName)
		prefs.setNodeName(nodeName)
		prefs.setLoggingDuration(duration)
		prefs.setLogFileSize(fileSize)
		prefs.setNumLogFiles(numFiles)
		prefs.setTpvLogFormat(outputType)
		prefs.setLogFileName(filename)
		prefs.setBufferSize(bufferSize)
		prefs.setUserId(user)
		prefs.setRefreshRate(refreshRate)

		params = [prefs]
		sig = ["com.ibm.ws.tpv.engine.UserPreferences"]

		target = "node=" + nodeName
		name = AdminControl.completeObjectName("type=TivoliPerfEngine," + target + ",*")
		mbeanObjectName = mgmt.ObjectName(name)

		display = nodeName + "\\" + serverName

		if action == "start":
			print "Calling TivoliPerfEngine.monitorServer on " + display
			AdminControl.invoke_jmx(mbeanObjectName, "monitorServer", params, sig)

			print "Calling TivoliPerfEngine.startLogging on " + display
			AdminControl.invoke_jmx(mbeanObjectName, "startLogging", params, sig)

			affectedCount = affectedCount + 1

		elif action == "stop":
			print "Calling TivoliPerfEngine.stopLogging on " + display
			AdminControl.invoke_jmx(mbeanObjectName, "stopLogging", params, sig)

			print "Calling TivoliPerfEngine.disableServer on " + display
			AdminControl.invoke_jmx(mbeanObjectName, "disableServer", params, sig)

			affectedCount = affectedCount + 1

		elif action == "list":
			print "Monitored Servers (by " + user + ")"
			print "======================"
			servers = AdminControl.invoke(name, "getMonitoredServers", user)
			if len(servers) > 0:
				isLoggingSig = ["com.ibm.ws.tpv.engine.utils.ServerBean"]
				for server in servers.split("\n"):
					pieces = server.split(".")
					bean = ServerBean(pieces[0], pieces[1])
					isLoggingParams = [bean]
					res = AdminControl.invoke_jmx(mbeanObjectName, "isServerLogging", isLoggingParams, isLoggingSig)
					perftarget = "node=" + nodeName + ",process=" + pieces[1]
					perfname = AdminControl.completeObjectName("type=Perf," + perftarget + ",*")
					print server + " ; Logging=" + str(res) + " ; Level=" + AdminControl.invoke(perfname, "getStatisticSet")
			break # otherwise we'll do the list for each server in the node -- TODO break outter loop too?

		elif action == "setlevel":
			target = target + ",process=" + serverName
			perfname = AdminControl.completeObjectName("type=Perf," + target + ",*")
			# none, basic, extended, all, custom
			print "Setting PMI level to " + pmilevel + " on " + serverName
			AdminControl.invoke(perfname, "setStatisticSet", pmilevel)
			AdminControl.invoke(perfname, "savePMIConfiguration")

			affectedCount = affectedCount + 1

		elif action == "debug":
			print "Debug"

		else:
			print "Unknown action " + action

print ""
print "Script finished. " + str(affectedCount) + " servers affected."

