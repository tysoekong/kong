local helpers = require "spec.helpers"
local cjson   = require "cjson"
local pl_file = require "pl.file"


local XML_TEMPLATE = [[
<?xml version="1.0" encoding="UTF-8"?>
<error>
  <message>%s</message>
</error>]]


local HTML_TEMPLATE = [[
<!doctype html>
<html>
  <head>
    <meta charset="utf-8">
    <title>Kong Error</title>
  </head>
  <body>
    <h1>Kong Error</h1>
    <p>%s.</p>
  </body>
</html>]]


local RESPONSE_CODE    = 504
local RESPONSE_MESSAGE = "The upstream server is timing out"


for _, strategy in helpers.each_strategy() do
  describe("Proxy errors Content-Type [#" .. strategy .. "]", function()
    local proxy_client

    describe("set via error_default_type", function()
      lazy_setup(function()
        local bp = helpers.get_db_utils(strategy, {
          "routes",
          "services",
        })

        local service = bp.services:insert {
          name            = "api-1",
          protocol        = "http",
          host            = helpers.blackhole_host,
          port            = 81,
          connect_timeout = 1,
        }

        bp.routes:insert {
          methods = { "GET", "HEAD" },
          service = service,
        }

        assert(helpers.start_kong {
          database           = strategy,
          prefix             = helpers.test_conf.prefix,
          nginx_conf         = "spec/fixtures/custom_nginx.template",
          error_default_type = "text/html",
        })
      end)

      lazy_teardown(function()
        helpers.stop_kong()
      end)

      before_each(function()
        proxy_client = helpers.proxy_client()
      end)

      after_each(function()
        if proxy_client then
          proxy_client:close()
        end
      end)

      it("no Accept header uses error_default_type", function()
        local res = assert(proxy_client:send {
          method  = "GET",
          path    = "/",
          headers = {
            accept = nil,
          }
        })

        local body = assert.res_status(RESPONSE_CODE, res)
        local html_message = string.format(HTML_TEMPLATE, RESPONSE_MESSAGE)
        assert.equal(html_message, body)
      end)

      it("HEAD request does not return a body", function()
        local res = assert(proxy_client:send {
          method  = "HEAD",
          path    = "/",
        })

        local body = assert.res_status(RESPONSE_CODE, res)
        assert.equal("", body)
      end)
    end)

    describe("not set explicitly", function()
      lazy_setup(function()
        local bp = helpers.get_db_utils(strategy, {
          "routes",
          "services",
        })

        local service = bp.services:insert {
          name            = "api-1",
          protocol        = "http",
          host            = helpers.blackhole_host,
          port            = 81,
          connect_timeout = 1,
        }

        bp.routes:insert {
          methods = { "GET", "HEAD" },
          service = service,
        }

        assert(helpers.start_kong {
          database           = strategy,
          prefix             = helpers.test_conf.prefix,
          nginx_conf         = "spec/fixtures/custom_nginx.template",
        })
      end)

      lazy_teardown(function()
        helpers.stop_kong()
      end)

      before_each(function()
        proxy_client = helpers.proxy_client()
      end)

      after_each(function()
        if proxy_client then
          proxy_client:close()
        end
      end)

      it("default error_default_type = text/plain", function()
        local res = assert(proxy_client:send {
          method  = "GET",
          path    = "/",
          headers = {
            accept = nil,
          }
        })

        local body = assert.res_status(RESPONSE_CODE, res)
        assert.equal(RESPONSE_MESSAGE, body)
      end)

      describe("Accept header modified Content-Type", function()
        it("text/html", function()
          local res = assert(proxy_client:send {
            method  = "GET",
            path    = "/",
            headers = {
              accept = "text/html",
            }
          })

          local body = assert.res_status(RESPONSE_CODE, res)
          local html_message = string.format(HTML_TEMPLATE, RESPONSE_MESSAGE)
          assert.equal(html_message, body)
        end)

        it("application/json", function()
          local res = assert(proxy_client:send {
            method  = "GET",
            path    = "/",
            headers = {
              accept = "application/json",
            }
          })

          local body = assert.res_status(RESPONSE_CODE, res)
          local json = cjson.decode(body)
          assert.equal(RESPONSE_MESSAGE, json.message)
        end)

        it("application/xml", function()
          local res = assert(proxy_client:send {
            method  = "GET",
            path    = "/",
            headers = {
              accept = "application/xml",
            }
          })

          local body = assert.res_status(RESPONSE_CODE, res)
          local xml_message = string.format(XML_TEMPLATE, RESPONSE_MESSAGE)
          assert.equal(xml_message, body)
        end)
      end)
    end)

    describe("Custom error templates", function()
      local html_template_path  = "spec/fixtures/error_templates/error_template.html"
      local plain_template_path = "spec/fixtures/error_templates/error_template.plain"
      local json_template_path  = "spec/fixtures/error_templates/error_template.json"
      local xml_template_path   = "spec/fixtures/error_templates/error_template.xml"

      lazy_setup(function()
        local bp = helpers.get_db_utils(strategy, {
          "routes",
          "services",
        })

        local service = bp.services:insert {
          name            = "api-1",
          protocol        = "http",
          host            = helpers.blackhole_host,
          port            = 81,
          connect_timeout = 1,
        }

        bp.routes:insert {
          methods = { "GET", "HEAD" },
          service = service,
        }

        assert(helpers.start_kong {
          database             = strategy,
          prefix               = helpers.test_conf.prefix,
          nginx_conf           = "spec/fixtures/custom_nginx.template",
          error_template_html  = html_template_path,
          error_template_plain = plain_template_path,
          error_template_json  = json_template_path,
          error_template_xml   = xml_template_path,
        })
      end)

      lazy_teardown(function()
        helpers.stop_kong()
      end)

      before_each(function()
        proxy_client = helpers.proxy_client()
      end)

      after_each(function()
        if proxy_client then
          proxy_client:close()
        end
      end)

      describe("Accept header modified Content-Type", function()
        it("text/html", function()
          local res = assert(proxy_client:send {
            method  = "GET",
            path    = "/",
            headers = {
              accept = "text/html",
            }
          })

          local body = assert.res_status(RESPONSE_CODE, res)
          local custom_template = pl_file.read(html_template_path)
          local html_message = string.format(custom_template, RESPONSE_MESSAGE)
          assert.equal(html_message, body)
        end)

        it("text/plain", function()
          local res = assert(proxy_client:send {
            method  = "GET",
            path    = "/",
            headers = {
              accept = "text/plain",
            }
          })

          local body = assert.res_status(RESPONSE_CODE, res)
          local custom_template = pl_file.read(plain_template_path)
          local html_message = string.format(custom_template, RESPONSE_MESSAGE)
          assert.equal(html_message, body)
        end)

        it("application/json", function()
          local res = assert(proxy_client:send {
            method  = "GET",
            path    = "/",
            headers = {
              accept = "application/json",
            }
          })

          local body = assert.res_status(RESPONSE_CODE, res)
          local json = cjson.decode(body)
          assert.equal(RESPONSE_MESSAGE, json.custom_template_message)
        end)

        it("application/xml", function()
          local res = assert(proxy_client:send {
            method  = "GET",
            path    = "/",
            headers = {
              accept = "application/xml",
            }
          })

          local body = assert.res_status(RESPONSE_CODE, res)
          local custom_template = pl_file.read(xml_template_path)
          local xml_message = string.format(custom_template, RESPONSE_MESSAGE)
          assert.equal(xml_message, body)
        end)

        describe("with q-values", function()
          it("defaults to 1 when q-value is not specified", function()
            local res = assert(proxy_client:send {
              method  = "GET",
              path    = "/",
              headers = {
                accept = "application/json;q=0.9,text/html,text/plain;q=0.9",
              }
            })

            local body = assert.res_status(RESPONSE_CODE, res)
            local custom_template = pl_file.read(html_template_path)
            local html_message = string.format(custom_template, RESPONSE_MESSAGE)
            assert.equal(html_message, body)
          end)

          it("picks highest q-value (json)", function()
            local res = assert(proxy_client:send {
              method  = "GET",
              path    = "/",
              headers = {
                accept = "text/plain;q=0.7,application/json;q=0.8,text/html;q=0.5",
              }
            })

            local body = assert.res_status(RESPONSE_CODE, res)
            local json = cjson.decode(body)
            assert.equal(RESPONSE_MESSAGE, json.custom_template_message)
          end)
        end)
      end)
    end)
  end)
end
