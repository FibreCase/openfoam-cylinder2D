#!/bin/bash
# This script generates the mesh for the cylinder2D case using GMSH and converts it to OpenFOAM format.

# Check your geometry file
# gmsh cylinder2D.geo

# Generate the mesh, in OpenFOAM 8, the default mesh format is msh2, so we specify it explicitly
gmsh cylinder2D.geo -3 -format msh2 -o cylinder2D.msh

# Check the mesh file 
# gmsh cylinder2D.msh