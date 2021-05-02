local function elem(name)
   local function tostr(v)
      if type(v) == "string" then
         return '"' .. v .. '"'
      else
         return tostring(v)
      end
   end

   return function(options)
      local data = "<" .. name
      
      if type(options) == "table" then
         for k, v in pairs(options) do
            if type(k) ~= "number" then
               data = data .. (v == false and "" or (" " .. k .. (v == true and "" or ("=" .. tostr(v)))))
            end
         end
      end
      return data 
         .. ">" 
         .. (type(options) == "table" and table.concat(options) or options)
         .. "</" .. name .. ">"
   end
end

return setmetatable({}, {
   __index = function(_, k) return elem(k) end
})
