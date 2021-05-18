import sys
import time

def usage(error):
  if error != "":
    print ""
    print "ERROR: " + error
    print ""

  print "usage: wsadmin -lang jython -f diagnostictrace.py --action [list|set] [--node NODE] [--server SERVER] [--trace SPECIFICATION] [--serverType APPLICATION_SERVER]"
  print "  If neither -node nor -server are specified, then all servers on all nodes will be processed."
  print "  If -node is specified but -server isn't, then all application servers on the node will be processed."
  print "  Use --serverType APPLICATION_SERVER to skip the deployment manager and node agents."
  sys.exit()

def info(obj):
  print "INFO [%s] %s" % (time.strftime("%Y-%m-%d %H:%M:%S %Z", time.localtime()), str(obj))

def warning(obj):
  print "WARN [%s] %s" % (time.strftime("%Y-%m-%d %H:%M:%S %Z", time.localtime()), str(obj))

def error(obj):
  print "ERR  [%s] %s" % (time.strftime("%Y-%m-%d %H:%M:%S %Z", time.localtime()), str(obj))

NAME = "diagnostictrace.py"
VERSION = "0.1.20210518"
verbose = 0
action = "list"
targetNode = ""
targetApplicationServer = ""
traceSpecification = ""
serverType = ""

info(NAME + " " + VERSION + " jython: " + str(sys.version_info))

l = len(sys.argv)
i = 0
help = 0
while i < l:
  arg = sys.argv[i]
  if arg == "--help" or arg == "--h" or arg == "--usage" or arg == "--?":
    help = 1
  elif arg == "--action":
    i = i + 1
    action = sys.argv[i]
  elif arg == "--node":
    i = i + 1
    targetNode = sys.argv[i]
  elif arg == "--server":
    i = i + 1
    targetApplicationServer = sys.argv[i]
  elif arg == "--trace":
    i = i + 1
    traceSpecification = sys.argv[i]
  elif arg == "--serverType":
    i = i + 1
    serverType = sys.argv[i]
  elif arg == "--verbose":
    verbose = 1
  else:
    info("WARNING: Unknown argument " + arg)
  i = i + 1

if help == 1:
  usage("")

if action == "set" and traceSpecification == "":
  usage("--trace option must be set")
	
info("Action: " + action)
if action == "set":
  info("Trace specification: " + traceSpecification)

def handleException(typ, val, tb):
  value = `val`
  sd = `tb.dumpStack()`
  sd = sd.replace("\\\\","/")
  error(value + " " + sd)

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

nodeList = listNodes()

for nodeObject in nodeList:

  nodeName = nodeObject.split("(")[0]

  if len(targetNode) > 0 and targetNode.lower() != nodeName.lower():
    info("Skipping node " + nodeName + " because it did not match targetNode")
    continue

  info("Processing node: " + nodeName)

  serverList = []
  try:
    serverList = listServers(serverType, nodeName)
  except:
    warning("Node agent appears to be not running or cannot be contacted: Node: " + nodeName)

  if verbose:
    info("Number of servers: " + str(len(serverList)))

  for serverObject in serverList:
    serverName = serverObject.split("(")[0]

    if len(targetApplicationServer) > 0 and targetApplicationServer.lower() != serverName.lower():
      if verbose:
        info("Skipping server " + serverName + " (node " + nodeName + ")")
      continue
    
    if action == "list":
      info("Listing trace settings for Node: " + nodeName + ", Server: " + serverName)
      try:
        runtimeTraceSpec = AdminControl.getAttribute(AdminControl.completeObjectName("type=TraceService,process=" + serverName + ",node=" + nodeName + ",*"), "traceSpecification")
        info("Current runtime diagnostic trace for Node: " + nodeName + ", Server: " + serverName + " is " + runtimeTraceSpec)
      except:
        #typ, val, tb = sys.exc_info()
        #handleException(typ, val, tb)
        warning("Server appears to be not running or cannot be contacted: Node: " + nodeName + ", Server: " + serverName)

    elif action == "set":
      info("Setting trace to " + traceSpecification + " for Node: " + nodeName + ", Server: " + serverName)
      try:
        AdminControl.setAttribute(AdminControl.completeObjectName("type=TraceService,process=" + serverName + ",node=" + nodeName + ",*"), "traceSpecification", traceSpecification)
        info("Successfully set runtime diagnostic trace for Node: " + nodeName + ", Server: " + serverName + " to " + traceSpecification)
      except:
        #typ, val, tb = sys.exc_info()
        #handleException(typ, val, tb)
        warning("Server appears to be not running or cannot be contacted: Node: " + nodeName + ", Server: " + serverName)

    else:
      usage("Unknown action " + action)

info("Script finished.")
