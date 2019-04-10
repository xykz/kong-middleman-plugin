return {
  no_consumer = true,
  fields = {
    url = {required = true, type = "string"},
    response = { required = true, default = "application/json", type = "string", enum = {"application/json", "text/plain"}},
    timeout = { default = 10000, type = "number" },
    keepalive = { default = 60000, type = "number" },
    readbody = { default = false, type = "boolean" }
  }
}