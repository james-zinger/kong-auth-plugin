local typedefs = require "kong.db.schema.typedefs"

local PLUGIN_NAME = "remote-auth"


local schema = {
  name = PLUGIN_NAME,
  fields = {
    -- the 'fields' array is the top-level entry with fields defined by Kong
    { consumer = typedefs.no_consumer },     -- this plugin cannot be configured on a consumer (typical for auth plugins)
    { protocols = typedefs.protocols_http }, -- http protocols only
    {
      config = {
        -- The 'config' record is the custom part of the plugin schema
        type = "record",
        fields = {
          -- a standard defined field (typedef), with some customizations
          {
            request_auth_header = typedefs.header_name {
              required = true,
              default = "X-Auth-Header",
            }
          },
          {
            auth_server = typedefs.url {
              required = true,
            }
          },
        },
        entity_checks = {},
      },
    },
  },
}

return schema
