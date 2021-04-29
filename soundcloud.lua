local querystring = require "querystring"
local https = require "https"
local http = require "http"
local json = require "json"
local url = require "url"
local fs = require "fs"
local dom = require "dom"

local apiurl = "https://api-v2.soundcloud.com"

function randomid()
   local ids = {"1ZblcwqkcM5jJpypOqMGosmsvOPj2yqW","5MlCU9alf35yL0Ub7owwSlLVcGLgiFIB"} -- TODO: Add more
   return ids[math.random(#ids)]
end

local function getjson(path, qs, cb)
   qs.client_id = randomid()
   
   local url = path .. "?" .. querystring.stringify(qs)
   local req = https.get(url, function(res)
      local data = ""
      res:on("data", function(chunk) data = data .. chunk end)
      res:on("end", function()
         if res.statusCode == 200 then
            cb(json.parse(data))
         else p(res)
         end
      end)
   end)
   req:on("error", function(err) p("Got error", err) end)
end


http.createServer(function(req, res)
   local uri = url.parse(req.url)
   if uri.pathname == "/" then
      local html = "<!DOCTYPE html>\n" .. dom.html {
         dom.body {
            dom.form {
               action = "/search",
               method = "get",
               target = "search",
               dom.input {
                  ["type"] = "text",
                  name = "query",
                  placeholder = "Search"
               },
               dom.input { ["type"] = "submit" }
            },
            dom.iframe {
               name = "search",
            },
            dom.iframe {
               name = "player",
            }
         }
      }

      res:setHeader("Content-Type", "text/html")
      res:setHeader("Content-Length", #html)
      res:finish(html)
   elseif uri.pathname == "/search" then
      local query = querystring.parse(uri.query)

      getjson(apiurl .. "/search/tracks", { q = query.query, limit = 20 }, function(o)
         local entries = {}
         for _, col in ipairs(o.collection) do
            -- local tc = col.media.transcodings[2]
            -- p(tc.url, col.permalink, col.user.permalink)
            -- assert(tc.format.protocol == "progressive")
            table.insert(entries, dom.div {
               dom.a { href = "/tracks/" .. tostring(col.id), target = "player", "Play" },
               dom.p(col.user.username .. ": " .. col.title)
            })
         end
         local html = "<!DOCTYPE html>\n" .. dom.html {
            dom.body(table.concat(entries))
         }
         
         res:setHeader("Content-Type", "text/html")
         res:setHeader("Content-Length", #html)
         res:finish(html)
      end)

   elseif uri.pathname:sub(1, 7) == "/tracks" then
      local id = uri.pathname:sub(9)
      local html = "<!DOCTYPE html>\n" .. dom.html {
         dom.body {
            dom.audio {
               controls = true,
               autoplay = true,
               src = "/track.mp3"
            }
         }
      }

      res:setHeader("Content-Type", "text/html")
      res:setHeader("Content-Length", #html)
      res:finish(html)
   elseif uri.pathname == "/track.mp3" then
      fs.stat("./track.mp3", function(err, stat)
         local range = "bytes 0-" .. tostring(stat.size) .. "/" .. tostring(stat.size)
         res:writeHead(200, {
            ["Content-Type"] = "audio/mpeg",
            ["Content-Length"] = stat.size,
            ["Accept-Ranges"] = "bytes",
            ["Content-Range"] = range,
         })
         
         fs.createReadStream("./track.mp3"):pipe(res)
      end)
   else
      res.statusCode = 200
      res:setHeader("Content-Type", "text/plain");
      res:finish("Not Found");
   end
end):listen(8080)

p("Running server at http://127.0.0.1:8080")
