local http = require "resty.http"
local url = require "socket.url"

local kong = kong
local _M = {}
local fmt = string.format

local function unauthorized(message)
  return { status = 401, message = message }
end

local function bad_gateway(message)
  return { status = 502, message = message }
end

local parsed_urls_cache = {}
-- Parse host url.
-- @param `url` host url
-- @return `parsed_url` a table with host details:
-- scheme, host, port, path, query, userinfo
local function parse_url(host_url)
  local parsed_url = parsed_urls_cache[host_url]

  if parsed_url then
    return parsed_url
  end

  parsed_url = url.parse(host_url)
  if not parsed_url.port then
    if parsed_url.scheme == "http" then
      parsed_url.port = 80
    elseif parsed_url.scheme == "https" then
      parsed_url.port = 443
    end
  end
  if not parsed_url.path then
    parsed_url.path = "/"
  end

  parsed_urls_cache[host_url] = parsed_url

  return parsed_url
end

local function request_auth(conf, request_token)
  local method = conf.auth_request_method
  local timeout = conf.auth_request_timeout
  local keepalive = conf.auth_request_keepalive
  local token_prefix = conf.auth_request_token_prefix
  local parsed_url = parse_url(conf.auth_request_url)
  local request_header = conf.auth_request_header
  local host = parsed_url.host
  local port = tonumber(parsed_url.port)

  local httpc = http.new()
  httpc:set_timeout(timeout)

  local headers = {}
  if token_prefix then
    headers[request_header] = token_prefix .. request_token
  else
    headers[request_header] = request_token
  end

  if conf.headers then
    for h, v in pairs(conf.headers) do
      headers[h] = headers[h] or v
    end
  end

  local auth_server_url = fmt("%s://%s:%d%s", parsed_url.scheme, host, port, parsed_url.path)

  local res, err = httpc:request_uri(auth_server_url, {
    method = method,
    headers = headers,
    keepalive_timeout = keepalive,
  })
  if not res then
    return nil, "failed request to " .. host .. ":" .. tostring(port) .. ": " .. err
  end

  if res.status >= 300 then
    return nil, "authentication failed with status: " .. res.status
  end

  local token = res.get_header(conf.auth_response_header)
  return token, nil
end


function _M.authenticate(conf)
  local request_header = conf.request_auth_header
  local request_token = kong.request.get_header(request_header)

  -- If the header is missing, then reject the request
  if not request_token then
    return unauthorized("Missing Token, Unauthorized")
  end

  -- Make remote request to check credentials
  local auth_token, err = request_auth(conf, request_token)
  if err then
    return unauthorized("Unauthorized: " .. err)
  end

  -- set header in forwarded request
  if auth_token then
    local service_auth_header = conf.service_auth_header
    kong.service.request.set_header(service_auth_header)
  else
    return bad_gateway("Upsteam Authentication server returned an empty response")
  end
end

return _M
