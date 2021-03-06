local component = require("component")
local computer = require("computer")
local term = require("term")
local unicode = require("unicode")
local event = require("event")
local fs = require("filesystem")
local seri = require("serialization")
local shell = require("shell")
local gpu = component.gpu

-----------------Проверка компа на соответствие сис. требованиям--------------------------

shell.execute("cd ..")
shell.setWorkingDirectory("")

--Создаем массив говна
local govno = {}

print(" ")
print("Analyzing computer for matching system requirements...")

if fs.get("bin/edit.lua") == nil or fs.get("bin/edit.lua").isReadOnly() then table.insert(govno, "You can't install MineOS on floppy disk. Run \"install\" in command line and install OpenOS from floppy to HDD first. After that you're be able to install MineOS from Pastebin.") end

--Если нашло какое-то несоответствие сис. требованиям, то написать, что именно не так
if #govno > 0 then
  print(" ")
  for i = 1, #govno do
    print(govno[i])
  end
  print(" ")
  return
else
  print("Done, everything's good. Proceed to downloading.")
  print(" ")
end

------------------------------------------------------------------------------------------

local lang

local applications

local padColor = 0x262626
local installerScale = 1

local timing = 0.2

-----------------------------СТАДИЯ ПОДГОТОВКИ-------------------------------------------

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

--БЕЗОПАСНАЯ ЗАГРУЗОЧКА
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
  { paste = "FrisKAY/MineOS-Server/master/lib/ECSAPI.lua", path = "lib/ECSAPI.lua" },
  { paste = "FrisKAY/MineOS-Server/master/lib/colorlib.lua", path = "lib/colorlib.lua" },
  { paste = "FrisKAY/MineOS-Server/master/lib/image.lua", path = "lib/image.lua" },
  { paste = "FrisKAY/MineOS-Server/master/lib/config.lua", path = "lib/config.lua" },
  { paste = "FrisKAY/MineOS-Server/master/MineOS/Icons/Languages.pic", path = "OpenOS-Archive/Icons/Languages.pic" },
  { paste = "FrisKAY/MineOS-Server/master/MineOS/Icons/OK.pic", path = "OpenOS-Archive/Icons/OK.pic" },
  { paste = "FrisKAY/MineOS-Server/master/MineOS/Icons/Downloading.pic", path = "OpenOS-Archive/Icons/Downloading.pic" },
  { paste = "FrisKAY/MineOS-Server/master/MineOS/Icons/OS_Logo.pic", path = "OpenOS-Archive/Icons/OS_Logo.pic" },
}

print("Downloading file list")
applications = seri.unserialize(getFromGitHubSafely(GitHubUserUrl .. "FrisKAY/OpenOS/main/1.6.0/Applications.txt", "Applications.txt"))
print(" ")

for i = 1, #preLoadApi do
  print("Downloading \"" .. fs.name(preLoadApi[i].path) .. "\"")
  getFromGitHubSafely(GitHubUserUrl .. preLoadApi[i].paste, preLoadApi[i].path)
end

print(" ")
print("Initialization stage is complete, loading installer")
print(" ")

package.loaded.ecs = nil
package.loaded.ECSAPI = nil
_G.ecs = require("ECSAPI")
_G.image = require("image")
_G.config = require("config")

local imageOS = image.load("OpenOS-Archive/Icons/OS_Logo.pic")
local imageLanguages = image.load("OpenOS-Archive/Icons/Languages.pic")
local imageDownloading = image.load("OpenOS-Archive/Icons/Downloading.pic")
local imageOK = image.load("OpenOS-Archive/Icons/OK.pic")

ecs.setScale(installerScale)

local xSize, ySize = gpu.getResolution()
local windowWidth = 80
local windowHeight = 2 + 16 + 2 + 3 + 2
local xWindow, yWindow = math.floor(xSize / 2 - windowWidth / 2), math.ceil(ySize / 2 - windowHeight / 2)
local xWindowEnd, yWindowEnd = xWindow + windowWidth - 1, yWindow + windowHeight - 1


-------------------------------------------------------------------------------------------

local function clear()
  ecs.blankWindow(xWindow, yWindow, windowWidth, windowHeight)
end

--ОБЪЕКТЫ
local obj = {}
local function newObj(class, name, ...)
  obj[class] = obj[class] or {}
  obj[class][name] = {...}
end

local function drawButton(name, isPressed)
  local buttonColor = 0x888888
  if isPressed then buttonColor = ecs.colors.blue end
  local d = { ecs.drawAdaptiveButton("auto", yWindowEnd - 3, 2, 1, name, buttonColor, 0xffffff) }
  newObj("buttons", name, d[1], d[2], d[3], d[4])
end

local function waitForClickOnButton(buttonName)
  while true do
    local e = { event.pull() }
    if e[1] == "touch" then
      if ecs.clickedAtArea(e[3], e[4], obj["buttons"][buttonName][1], obj["buttons"][buttonName][2], obj["buttons"][buttonName][3], obj["buttons"][buttonName][4]) then
        drawButton(buttonName, true)
        os.sleep(timing)
        break
      end
    end
  end
end


ecs.prepareToExit()

------------------------------ВЫБОР Версии------------------------------------

local downloadVersion = false

do

  clear()

  image.draw(math.ceil(xSize / 2 - 30), yWindow + 2, imageLanguages)

  --кнопа
  drawButton("Select Version",false)

  waitForClickOnButton("Select Version")

  local data = ecs.universalWindow("auto", "auto", 36, 0x262626, true,
    {"EmptyLine"},
    {"CenterText", ecs.colors.orange, "Select Version"},
    {"EmptyLine"},
    {"Select", 0xFFFFFF, ecs.colors.green, "1.6.0", "1.5.0"},
    {"EmptyLine"},
    {"Button", {ecs.colors.orange, 0x262626, "->"}}
  )

  --УСТАНАВЛИВАЕМ НУЖНУЮ ВЕРСИЮ
  versiondown = data[1]
  
end

------------------------------ВЫБОР ДОПОВ------------------------------------

local downloadWallpapers, showHelpTips, downloadAllApps = false, false, false

do

  clear()

  image.draw(math.ceil(xSize / 2 - 30), yWindow + 2, imageLanguages)

  --кнопа
  drawButton("Select Languages",false)

  waitForClickOnButton("Select Languages")

  local data = ecs.universalWindow("auto", "auto", 36, 0x262626, true,
    {"EmptyLine"},
    {"CenterText", ecs.colors.orange, "Select Languages"},
    {"EmptyLine"},
    {"Select", 0xFFFFFF, ecs.colors.green, "Russian", "English"},
    {"EmptyLine"},
	{"Switch", 0xF2B233, 0xffffff, 0xFFFFFF, "Download Test", false},
    {"EmptyLine"},
    {"Button", {ecs.colors.orange, 0x262626, "->"}}
  )

  --УСТАНАВЛИВАЕМ НУЖНЫЙ ЯЗЫК
  _G.OSSettings = { language = data[1] }
  ecs.saveOSSettings()

  --Качаем язык
  ecs.info("auto", "auto", " ", " Installing language packages...")
  local pathToLang = "OpenOS-Archive/Language.lang"
  getFromGitHubSafely(GitHubUserUrl .. "FrisKAY/MineOS-Server/master/Installer/" .. _G.OSSettings.language .. ".lang", pathToLang)
  getFromGitHubSafely(GitHubUserUrl .. "FrisKAY/MineOS-Server/master/MineOS/License/" .. _G.OSSettings.language .. ".txt", "OpenOS-Archive/License.txt")
  
  --Ставим язык
  lang = config.readAll(pathToLang)

end


------------------------------СТАВИТЬ ЛИ ОСЬ------------------------------------

do
  clear()

  image.draw(math.ceil(xSize / 2 - 15), yWindow + 2, imageOS)

  --Текстик по центру
  gpu.setBackground(ecs.windowColors.background)
  gpu.setForeground(ecs.colors.gray)
  ecs.centerText("x", yWindowEnd - 5 , lang.beginOsInstall)

  --кнопа
  drawButton("->",false)

  waitForClickOnButton("->")

end

------------------------------ЛИЦ СОГЛАЩЕНЬКА------------------------------------------

do
  clear()
  
  --Откуда рисовать условия согл
  local from = 1
  local xText, yText, TextWidth, TextHeight = xWindow + 4, yWindow + 2, windowWidth - 8, windowHeight - 7

  --Читаем файл с лиц соглл
  local lines = {}
  local file = io.open("OpenOS-Archive/License.txt", "r")
  for line in file:lines() do
    table.insert(lines, line)
  end
  file:close()

  --Штуку рисуем
  ecs.textField(xText, yText, TextWidth, TextHeight, lines, from, 0xffffff, 0x262626, 0x888888, ecs.colors.blue)

  --Инфо рисуем
  --ecs.centerText("x", yWindowEnd - 5 ,"Принимаете ли вы условия лицензионного соглашения?")

  --кнопа
  drawButton(lang.acceptLicense, false)

  while true do
    local e = { event.pull() }
    if e[1] == "touch" then
      if ecs.clickedAtArea(e[3], e[4], obj["buttons"][lang.acceptLicense][1], obj["buttons"][lang.acceptLicense][2], obj["buttons"][lang.acceptLicense][3], obj["buttons"][lang.acceptLicense][4]) then
        drawButton(lang.acceptLicense, true)
        os.sleep(timing)
        break
      end
    elseif e[1] == "scroll" then
      if e[5] == -1 then
        if from < #lines then from = from + 1; ecs.textField(xText, yText, TextWidth, TextHeight, lines, from, 0xffffff, 0x262626, 0x888888, ecs.colors.blue) end
      else
        if from > 1 then from = from - 1; ecs.textField(xText, yText, TextWidth, TextHeight, lines, from, 0xffffff, 0x262626, 0x888888, ecs.colors.blue) end
      end
    end
  end
end


--------------------------СТАДИЯ ЗАГРУЗКИ-----------------------------------

do
  local barWidth = math.floor(windowWidth * 2 / 3)
  local xBar = math.floor(xSize/2-barWidth/2)
  local yBar = yWindowEnd - 3

  local function drawInfo(x, y, info)
    ecs.square(x, y, barWidth, 1, ecs.windowColors.background)
    ecs.colorText(x, y, ecs.colors.gray, info)
  end

  ecs.blankWindow(xWindow,yWindow,windowWidth,windowHeight)

  image.draw(math.floor(xSize / 2 - 33), yWindow + 2, imageDownloading)

  ecs.colorTextWithBack(xBar, yBar - 1, ecs.colors.gray, ecs.windowColors.background, lang.osInstallation)
  ecs.progressBar(xBar, yBar, barWidth, 1, 0xcccccc, ecs.colors.blue, 0)
  os.sleep(timing)

 local thingsToDownload = {}
  for i = 1, #applications do
    if 
      (applications[i].type == "Script" and downloadtest)
	  or
	  (applications[i].type == ""..versiondown.."")
      or
      (applications[i].forceDownload)
    then
      table.insert(thingsToDownload, applications[i])
    end
    --Подчищаем за собой, а то мусора нынче много
    applications[i] = nil
  end

  for app = 1, #thingsToDownload do
    --ВСЕ ДЛЯ ГРАФОНА
    drawInfo(xBar, yBar + 1, lang.downloading .. " " .. thingsToDownload[app]["name"])
    local percent = app / #thingsToDownload * 100
    ecs.progressBar(xBar, yBar, barWidth, 1, 0xcccccc, ecs.colors.blue, percent)

    ecs.getOSApplication(thingsToDownload[i])
  end

  os.sleep(timing)
end


--------------------------СТАДИЯ ПЕРЕЗАГРУЗКИ КОМПА-----------------------------------

ecs.blankWindow(xWindow,yWindow,windowWidth,windowHeight)

image.draw(math.floor(xSize/2 - 16), math.floor(ySize/2 - 11), imageOK)

--Текстик по центру
gpu.setBackground(ecs.windowColors.background)
gpu.setForeground(ecs.colors.gray)
ecs.centerText("x",yWindowEnd - 5, lang.needToRestart)

--Кнопа
drawButton(lang.restart, false)
waitForClickOnButton(lang.restart)
ecs.prepareToExit()

computer.shutdown(true)