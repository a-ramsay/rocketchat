-- drunner service configuration for ROCKETCHAT
-- based on https://raw.githubusercontent.com/RocketChat/Rocket.Chat/develop/docker-compose.yml
-- and https://github.com/docker-library/docs/tree/master/rocket.chat

rccontainer="drunner-${SERVICENAME}-rocketchat"
dbcontainer="drunner-${SERVICENAME}-mongodb"
caddycontainer="drunner-${SERVICENAME}-caddy"
dbvolume="drunner-${SERVICENAME}-database"
certvolume="drunner-${SERVICENAME}-certvolume"

-- addconfig( VARIABLENAME, DEFAULTVALUE, DESCRIPTION )
addconfig("PORT","80","The port to run rocketchat on.")

function start_mongo()
    -- fire up the mongodb server.
    result=docker("run",
    "--name",dbcontainer,
    "-v", dbvolume .. ":/data/db",
    "-d","mongo:3.2",
    "--smallfiles",
    "--oplogSize","128",
    "--replSet","rs0")

    if result~=0 then
      print("Failed to start mongodb.")
    end

-- Wait for port 27017 to come up in dbcontainer.
    if not dockerwait(dbcontainer, "27017") then
      print("Mongodb didn't seem to start?")
    end

    -- run the mongo replica config
    result=docker("run","--rm",
    "--link", dbcontainer.. ":db",
    "mongo:3.2",
    "mongo","db/rocketchat","--eval",
    "rs.initiate({ _id: 'rs0', members: [ { _id: 0, host: 'localhost:27017' } ]})"
    )

    if result~=0 then
      print("Mongodb replica init failed")
    end

end

function start_rocketchat()
    -- and rocketchat
    result=docker("run",
    "--name",rccontainer,
    "-p","80:3000",
    "--link", dbcontainer .. ":db",
    "--env","MONGO_URL=mongodb://db:27017/rocketchat",
    "--env","MONGO_OPLOG_URL=mongodb://db:27017/local",
    "-d","rocket.chat")

    if result~=0 then
      print("Failed to start rocketchat on port ${PORT}.")
    end
end

function start_caddy()
  result=docker("run",
    "--name",caddycontainer,
    "-p","${PORT}:443",
    "-v", certvolume .. ":/root/.caddy",
  )

function start()
   if (dockerrunning(dbcontainer)) then
      print("rocketchat is already running.")
   else
      start_mongo()
      start_rocketchat()
      start_caddy()
   end
end

function stop()
  dockerstop(dbcontainer)
  dockerstop(rccontainer)
  dockerstop(caddycontainer)
end

function uninstall()
   stop()
   -- we retain the database volume
end

function obliterate()
   stop()
   dockerdeletevolume(dbvolume)
   dockerdeletevolume(certvolume)
end

-- install
function install()
  dockerpull("mongo:3.2")
  dockerpull("rocket.chat")
  dockerpull("zzrot/alpine-caddy")
  dockercreatevolume(dbvolume)
  dockercreatevolume(certvolume)
--  start() ?
end

function backup()
   docker("pause",rccontainer)
   docker("pause",dbcontainer)

   dockerbackup(dbvolume)
   dockerbackup(certvolume)

   docker("unpause",dbcontainer)
   docker("unpause",rccontainer)
end

function restore()
   dockerrestore(dbvolume)
   dockerrestore(certvolume)
end

function help()
   return [[
   NAME
      ${SERVICENAME} - Run a rocket.chat server on the given port.

   SYNOPSIS
      ${SERVICENAME} help             - This help
      ${SERVICENAME} configure port   - Set port
      ${SERVICENAME} start            - Make it go!
      ${SERVICENAME} stop             - Stop it

   DESCRIPTION
      Built from ${IMAGENAME}.
   ]]
end
