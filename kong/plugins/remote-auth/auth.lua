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
  local parsed_url = parse_url(conf.auth_request_url)
  local request_header = conf.auth_request_token_header
  local response_token_header = conf.auth_response_token_header
  local host = parsed_url.host
  local port = tonumber(parsed_url.port)

  local httpc = http.new()
  httpc:set_timeout(timeout)

  local headers = {
    [request_header] = request_token
  }

  if conf.auth_request_headers then
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

  local token = res.headers[response_token_header]
  return token, nil
end

local function authenticate(conf)
  local request_header = conf.consumer_auth_header
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
    local service_token_prefix = conf.service_auth_header_value_prefix

    local header_value = auth_token
    if service_token_prefix then
      header_value = service_token_prefix .. auth_token
    end
    kong.service.request.set_header(service_auth_header, header_value)
    kong.response.set_header(conf.auth_response_token_header, auth_token)
  else
    return bad_gateway("Upsteam Authentication server returned an empty response")
  end
end

function _M.authenticate(conf)
  local err = authenticate(conf)
  if err then
    kong.response.error(err.status, err.message, err.headers)
  end
end

return _M
