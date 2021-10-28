local component = require("component")
local computer = require("computer")
local term = require("term")
local unicode = require("unicode")
local event = require("event")
local fs = require("filesystem")
local seri = require("serialization")
local shell = require("shell")
local gpu = component.gpu
local vers = "-none-"
 
function install_160(msg)
  local function request(url)
  local success, response = pcall(component.internet.request, url)
  if success then
    local responseData = ""
    while true do
      local data, responseChunk = response.read() 
      if data then
        responseData = responseData .. data
      else
        if responseChunk then
          return false, responseChunk
        else
          return responseData
        end
      end
    end
  else
    return false, reason
  end
end
 
--ЗАГРУЗОЧКА
local function getFromGitHubSafely(url, path)
  local success, reason = request(url)
  if success then
    fs.makeDirectory(fs.path(path) or "")
    fs.remove(path)
    local file = io.open(path, "w")
    file:write(success)
    file:close()
    return success
  else
    io.stderr:write("Can't download \"" .. url .. "\"!\n")
    return -1
  end
end
 
local GitHubUserUrl = "https://raw.githubusercontent.com/"
 
 
--------------------------------- Стадия стартовой загрузки всего необходимого ---------------------------------
 
 
local preLoadApi = {
  { paste = "FrisKAY/OpenOS/main/1.6.0/usr/misc/greetings.txt", path = "usr/misc/greetings.txt" },
}
 
for i = 1, #preLoadApi do
  print("Install \"" .. fs.name(preLoadApi[i].path) .. "\"")
  getFromGitHubSafely(GitHubUserUrl .. preLoadApi[i].paste, preLoadApi[i].path)
end
 
local file = io.open("usr/misc/greetings.txt", "w")
file:write("local success, reason = pcall(loadfile(\"init.lua\")); if not success then print(\"Error: \" .. tostring(reason)) end")
file:close()
print("Done OpenOS: 1.6.0")
vers = "1.6.0 [Virtual]"
end
 
function install_150(msg)
  print("This script displays a welcome message and counts the number " ..
  "of times it has been called. The welcome message can be set in the " ..
  "config file /etc/rc.cfg")
  print("Done OpenOS: 1.5.0")
  vers = "1.5.0 [Virtual]"
end
 
function version(msg)
  print("OpenOS version: \"" .. vers .. "\"!\n")
end