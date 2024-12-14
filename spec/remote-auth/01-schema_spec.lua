local PLUGIN_NAME = "remote-auth"


-- helper function to validate data against a schema
local validate
do
  local validate_entity = require("spec.helpers").validate_plugin_config_schema
  local plugin_schema = require("kong.plugins." .. PLUGIN_NAME .. ".schema")

  function validate(data)
    return validate_entity(data, plugin_schema)
  end
end


describe(PLUGIN_NAME .. ": (schema)", function()
  it("accepts request_auth_header configuration", function()
    local ok, err = validate({
      request_auth_header = "X-Test_header",
      auth_server = "http://example.com/auth",
    })
    assert.is_nil(err)
    assert.is_truthy(ok)
  end)
end)
