local cjson = require "cjson"
local url = require "socket.url"
local http = require "resty.http"

local kong_response = kong.response

local get_headers = ngx.req.get_headers
local get_uri_args = ngx.req.get_uri_args
local read_body = ngx.req.read_body
local get_body = ngx.req.get_body_data
local get_method = ngx.req.get_method

local HTTP = "http"
local HTTPS = "https"

local _M = {}

local function parse_url(host_url)
  local parsed_url = url.parse(host_url)
  if not parsed_url.port then
    if parsed_url.scheme == HTTP then
      parsed_url.port = 80
     elseif parsed_url.scheme == HTTPS then
      parsed_url.port = 443
     end
  end
  if not parsed_url.path then
    parsed_url.path = "/"
  end
  return parsed_url
end

function _M.execute(conf)
  if not conf.run_on_preflight and get_method() == "OPTIONS" then
    return
  end

  kong_response.set_header("Content-Type", conf.response)

  local ok, err
  local parsed_url = parse_url(conf.url)
  local host = parsed_url.host
  local port = tonumber(parsed_url.port)
  local payload = _M.compose_payload(parsed_url, conf)

  local httpc = http.new()
  httpc:set_timeout(conf.timeout)

  ok, err = httpc:connect(host, port)
  if not ok then
    kong.log.err("failed to connect to " .. host .. ":" .. tostring(port) .. ": ", err)
    return _M.compose_err_response(err)
  end

  if parsed_url.scheme == HTTPS then
    local _, err = httpc:ssl_handshake(true, host, false)
    if err then
      kong.log.err("failed to do SSL handshake with " .. host .. ":" .. tostring(port) .. ": ", err)
    end
  end

  local res, err = httpc:request({
    path = parsed_url.path,
    query = parsed_url.query,
    body = payload,
    method = "POST",
    version = 1.1,
    ssl_verify = false,
    headers = {
      ["Content-Type"] = "application/json",
      ["Host"] = ngx.var.server_addr,
      ["Connection"] = "Keep-Alive",
      ["Content-Length"] = #payload
    }
  })
  if err then
    kong.log.err("failed to request to " .. host .. ":" .. tostring(port) .. ": ", err)
    return _M.compose_err_response(err)
  end

  local body, err = res:read_body()
  if err then
    kong.log.err("failed to read body " .. host .. ":" .. tostring(port) .. ": ", err)
    return _M.compose_err_response(err)
  end

  ok, err = httpc:set_keepalive(conf.keepalive)
  if not ok then
    kong.log.err("failed to keepalive to " .. host .. ":" .. tostring(port) .. ": ", err)
  end

  local status_code = res.status
  if status_code > 299 then
    return kong_response.exit(status_code, body)
  end
end

function _M.compose_err_response(err)
  local body = [[{"message":"]] .. err .. [["}]]
  return kong_response.exit(500, body)
end

function _M.compose_payload(parsed_url, conf)
    local headers = get_headers()
    local uri_args = get_uri_args()
    local next = next

    headers["target_uri"] = ngx.var.request_uri
    headers["target_method"] = ngx.var.request_method
    
    -- 读取头部
    local ok, raw_json_headers = pcall(cjson.encode, headers)
    if not ok then
      raw_json_headers = "{}"
    end

    -- 读取内容
    local body_data
    if conf.readbody then
      read_body()
      body_data = get_body()
    end

    local raw_json_body_data
    if type(body_data) == "string" then
      raw_json_body_data = string.match(body_data, "%b{}")
      if not raw_json_body_data then
        ok, raw_json_body_data = pcall(cjson.encode, body_data)
        if not ok then
          raw_json_body_data = "{}"
        end
      end
    else
      raw_json_body_data = "{}"
    end

    -- 读取参数
    local raw_json_uri_args
    if next(uri_args) then 
      raw_json_uri_args = cjson.encode(uri_args) 
    else
      -- Empty Lua table gets encoded into an empty array whereas a non-empty one is encoded to JSON object.
      -- Set an empty object for the consistency.
      raw_json_uri_args = "{}"
    end

    local payload_body = [[{"headers":]] .. raw_json_headers .. [[,"uri_args":]] .. raw_json_uri_args.. [[,"body_data":]] .. raw_json_body_data .. [[}]]

    return payload_body
end

return _M
