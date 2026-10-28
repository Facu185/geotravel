-- Perfil "ruta mas corta": igual al car.lua oficial de OSRM (sentidos, giros prohibidos, accesos), pero con
-- weight_name = 'distance': el costo de cada tramo es su longitud, sin penalizar giros ni velocidades.
-- La duracion que devuelve OSRM sigue estimandose con las velocidades del perfil car.
package.path = "/opt/?.lua;/opt/lib/?.lua;" .. package.path

local car = require("car")

local M = {}

function M.setup()
  local profile = car.setup()
  profile.properties.weight_name = "distance"
  return profile
end

M.process_node = car.process_node
M.process_way = car.process_way
M.process_turn = car.process_turn

return M
