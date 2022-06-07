import sys
import time

def usage(error):
  if error != "":
    print ""
    print "ERROR: " + error
    print ""

  print "usage: wsadmin -lang jython -f enablepmi_odr.py [--node NODE] [--server ODRSERVER]"
  print "  If neither -node nor -server are specified, then all ODRs on all nodes will be processed."
  print "  If -node is specified but -server isn't, then all ODRs on the node will be processed."
  sys.exit()

def info(obj):
  print "INFO [%s] %s" % (time.strftime("%Y-%m-%d %H:%M:%S %Z", time.localtime()), str(obj))

def warning(obj):
  print "WARN [%s] %s" % (time.strftime("%Y-%m-%d %H:%M:%S %Z", time.localtime()), str(obj))

def error(obj):
  print "ERR  [%s] %s" % (time.strftime("%Y-%m-%d %H:%M:%S %Z", time.localtime()), str(obj))

NAME = "enablepmi_odr.py"
VERSION = "0.1.20220607"
verbose = 0
action = "enable"
targetNode = ""
targetApplicationServer = ""

# wsadmin>print AdminTask.listServerTypes() 
# TOMCAT_SERVER
# APPLICATION_SERVER
# LIBERTY_SERVER
# CUSTOMHTTP_SERVER
# WASCE_SERVER
# ONDEMAND_ROUTER
# APACHE_SERVER
# WEB_SERVER
# PROXY_SERVER
# WASAPP_SERVER
# JBOSS_SERVER
# WEBLOGIC_SERVER
# GENERIC_SERVER
# PHP_SERVER
serverType = "ONDEMAND_ROUTER"

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

info("Action: " + action)

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

  nodeChanged = 0

  for serverObject in serverList:
    serverName = serverObject.split("(")[0]

    if len(targetApplicationServer) > 0 and targetApplicationServer.lower() != serverName.lower():
      if verbose:
        info("Skipping server " + serverName + " (node " + nodeName + ")")
      continue
    
    if action == "enable":
      info("Enabling ODR PMI settings for Node: " + nodeName + ", Server: " + serverName)
      try:
        pmiModule = AdminConfig.list("PMIModule", serverObject)
        pxyMod = AdminConfig.create('PMIModule', pmiModule, [['moduleName', 'Proxy Module'], ['type', 'com.ibm.ws.proxy.stat.http.proxyModule,com.ibm.ws.proxy.stat.sip.sipProxyModule'], ['enable', '']])
        httpPxyMod = AdminConfig.create('PMIModule', pxyMod, [['moduleName', 'Http Proxy'], ['type', 'com.ibm.ws.proxy.stat.http.proxyModule'], ['enable', '']])
        sipPxyMod = AdminConfig.create('PMIModule', pxyMod, [['moduleName', 'SIP Proxy'], ['type', 'com.ibm.ws.proxy.stat.sip.sipProxyModule'], ['enable', '']])
        nodeChanged = 1
        info("Queued enablement of PMI settings for Node: " + nodeName + ", Server: " + serverName)
      except:
        #typ, val, tb = sys.exc_info()
        #handleException(typ, val, tb)
        warning("Server appears to be not running or cannot be contacted: Node: " + nodeName + ", Server: " + serverName)

    else:
      usage("Unknown action " + action)
  
  if nodeChanged == 1:
    info("Saving changes for node: " + nodeName)
    AdminConfig.save()
    info("Saved changes for node: " + nodeName)
    info("Synchronizing node: " + nodeName)
    AdminNodeManagement.syncNode(nodeName)
    info("Successfully synchronized node: " + nodeName)
    info("NOTE: You will need to restart the affected ODR(s)")

info("Script finished.")
