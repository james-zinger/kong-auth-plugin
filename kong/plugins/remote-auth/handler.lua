local auth = require "kong.plugins.remote-auth.auth"

local plugin = {
  PRIORITY = 1000,
  VERSION = "0.1.0",
}


function plugin:access(plugin_conf)
  return auth.authenticate(plugin_conf)
end

return plugin
