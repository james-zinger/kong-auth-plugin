local PLUGIN_NAME = "remote-auth"

describe(PLUGIN_NAME .. ": (unit) ", function()
  local plugin, config
  local actual_require
  local mock_auth_response_status
  local mock_auth_calls
  local mock_request_header_value
  local mock_auth_response_headers
  local mock_request_set_headers_calls
  local request_header_name

  setup(function()
    mock_auth_calls = {}
    mock_auth_response_headers = {}
    mock_auth_set_headers_calls = {}
    mock_request_set_headers_calls = {}
    actual_require = _G.require
    _G.kong = { -- mock the basic Kong function we use in our plugin
      request = {
        get_header = function(name)
          if name == request_header_name then
            return mock_request_header_value
          end
          return nil
        end,
      },
      service = {
        request = {
          set_header = function(name, value)
            mock_request_set_headers_calls[#mock_request_set_headers_calls + 1] = { name = name, value = value }
          end,
        }
      }
    }
    _G.require = function(modname)
      if modname == "resty.http" then
        return {
          new = function()
            http = {}
            http.set_timeout = function(self, timeout)

            end
            http.request_uri = function(self, url, opts)
              mock_auth_calls[#mock_auth_calls + 1] = { url = url, opts = opts }
              if mock_auth_response_status then
                return {
                  status = mock_auth_response_status,
                  get_header = function(name)
                    return mock_auth_response_headers[name]
                  end
                }
              else
                return nil
              end
            end
            return http
          end
        }
      else
        -- For anything else, return actual.
        return actual_require(modname)
      end
    end

    -- load the plugin code
    plugin = require("kong.plugins." .. PLUGIN_NAME .. ".handler")
  end)

  teardown(function()
    _G.require = actual_require
  end)


  before_each(function()
    request_header_name = "X-Auth"
    -- clear the upvalues to prevent test results mixing between tests
    config = {
      request_auth_url = "http://127.0.0.1:2101/auth",
      inbound_auth_header = "X-Auth",
      auth_response_token_header = "X-Token",
      auth_request_token_header = "Authorization",
      auth_request_method = "POST",
      auth_request_keepalive = 10000,
      service_auth_header = "X-Auth",
    }
  end)

  after_each(function()
    mock_auth_calls = {}
    mock_auth_response_status = nil
    mock_request_header_value = nil
    mock_auth_response_headers = {}
  end)



  it("gets request url", function()
    mock_auth_response_status = 200
    mock_request_header_value = "asdf1234"
    mock_auth_response_headers = {
      ["X-Token"] = "foobarbaz98765"
    }
    local result = plugin:access(config)
    assert.equal(mock_auth_calls[1].opts.headers.Authorization, "asdf1234")
    assert.same(mock_auth_calls, { {
      url = "http://127.0.0.1:2101/auth",
      opts = {
        method = "POST",
        headers = { Authorization = "asdf1234" },
        keepalive_timeout = 10000,
      }
    } })
    assert.same(mock_request_set_headers_calls, { { name = "X-Auth", value = "foobarbaz98765" } })
    assert.is_nil(result)
  end)


  -- it("gets a 'bye-world' header on a response", function()
  --   plugin:header_filter(config)
  --   assert.equal("bye-world", header_name)
  --   assert.equal("this is on the response", header_value)
  -- end)
end)
