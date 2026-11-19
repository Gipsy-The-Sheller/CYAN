# Copyright (C) 2018  INRIA
#
# Treerecs is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# Treerecs is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

# Add _USE_MATH_DEFINES for cmath.
add_definitions(-D_USE_MATH_DEFINES)

# PLL library
set(BUILD_LIBPLL_STATIC TRUE)

# PLL modules
set(BUILD_PLLMODULES_STATIC TRUE)
add_subdirectory(pll-modules)
set(PLLMODULES_INCLUDE_DIRS
  ${PLLMOD_EXPORTED_INCLUDE_PATH}
  CACHE INTERNAL "PLL modules: Include dirs" FORCE)
set(PLL_INCLUDE_DIRS
  ${CMAKE_CURRENT_SOURCE_DIR}/pll-modules/libs/libpll/
  CACHE INTERNAL "PLL: Include dirs" FORCE)
