# OpenFOAM Cylinder Flow Kármán Vortex Street Simulation

This project uses OpenFOAM 8 to simulate the Kármán vortex street formed by two-dimensional flow past a circular cylinder. Geometry modeling and mesh generation are handled with Gmsh, the flow field is solved with `icoFoam`, and results are post-processed in ParaView.

## Project Overview

- Cylinder diameter: $D = 0.01\,\text{m}$
- Fluid density: $\rho = 1.225\,\text{kg/m}^3$
- Inlet velocity: $U = 34.7188\,\text{m/s}$
- Reynolds number: $Re = 100$
- Far-field gauge pressure: $p_{\infty} = 444.038\,\text{Pa}$
- Problem type: two-dimensional external flow
- Geometry and mesh generation: Gmsh
- CFD solver: OpenFOAM 8 (`icoFoam`, laminar, transient, PISO)
- Post-processing: ParaView

The repository contains the following main directories:

- `geometry/`: geometry definition and mesh generation scripts for the cylinder-flow domain
- `cases/Re100/`: the OpenFOAM case for the Reynolds number 100 setup
- `scripts/`: auxiliary scripts (e.g., force-coefficient CSV post-processing)
- `docs/`: technical documentation with governing equations, numerical schemes, and solver details

## Workflow

1. Define the two-dimensional cylinder-flow domain in `geometry/cylinder2D.geo`.
2. Run `geometry/generate.sh` to generate the mesh with Gmsh (msh2 format for OpenFOAM 8 compatibility).
3. In `cases/Re100/`, run `Allrun.sh` which performs mesh conversion, boundary patching, mesh checking, parallel decomposition, solving, and result reconstruction.
4. Use ParaView to inspect the velocity field, pressure field, and vortex street evolution.

## Environment

The project runs OpenFOAM 8 through Docker using the `openfoam/openfoam8-paraview56:latest` image. A VS Code shell task is provided for one-click container launch.

### Prerequisites

- Docker
- Visual Studio Code

### Start the container

In VS Code, open the Command Palette (`Ctrl+Shift+P`) and run:

> **Tasks: Run Task** → **OpenFOAM Terminal**

This launches an interactive shell inside the OpenFOAM 8 container with the project directory mounted at `/workspace`. The container is created with `--user 1000:1000` so that generated files have the same ownership as the host user.

Alternatively, run the container manually:

```bash
docker run -it --rm --user 1000:1000 -v .:/workspace openfoam/openfoam8-paraview56:latest
```

## Usage

### 1. Generate the mesh

```bash
cd geometry
bash generate.sh
```

The mesh file is generated as `geometry/cylinder2D.msh`. The script uses Gmsh's msh2 format explicitly (`-format msh2`), which is required by `gmshToFoam` in OpenFOAM 8.

### 2. Run the case

```bash
cd cases/Re100
bash Allrun.sh
```

The script performs the following steps automatically:

1. Convert the Gmsh mesh to OpenFOAM format (`gmshToFoam`)
2. Patch boundary types via `foamDictionary` (`frontAndBack → empty`, `cylinder → wall`)
3. Check mesh quality (`checkMesh`)
4. Decompose the domain for parallel execution (`decomposePar`, 16 cores, scotch)
5. Solve with `icoFoam` in parallel (`mpirun -np 16 icoFoam -parallel`)
6. Reconstruct the full fields (`reconstructPar`)
7. Clean up `processor*/` directories

After `gmshToFoam` and boundary patching, the `constant/polyMesh/boundary` file contains:

```
(
    frontAndBack
    {
        type            empty;
        nFaces          154456;
        startFace       117866;
    }
    cylinder
    {
        type            wall;
        nFaces          236;
        startFace       272322;
    }
    farfield
    {
        type            patch;
        nFaces          120;
        startFace       272558;
    }
    outlet
    {
        type            patch;
        nFaces          40;
        startFace       272678;
    }
    inlet
    {
        type            patch;
        nFaces          40;
        startFace       272718;
    }
)
```

### 3. Post-process the results

After the solve finishes, open the case directory in ParaView and inspect velocity contours, pressure contours, vorticity, and the wake oscillation pattern. Force coefficient data is written to `postProcessing/forceCoeffs/0/coefficient.dat`.

## Directory Structure

```text
.
├── geometry/          # Gmsh .geo and generate.sh
├── cases/Re100/       # OpenFOAM case (0/, constant/, system/, Allrun.sh)
├── scripts/           # Post-processing utilities
├── docs/              # Technical documentation
└── .vscode/           # VS Code task for container launch
```

## Notes

- The goal of this project is to reproduce the vortex shedding characteristics of cylinder flow at $Re = 100$.
- If you need to adjust the Reynolds number, mesh density, or domain size, start by editing `geometry/cylinder2D.geo` and the corresponding OpenFOAM physical parameter settings.
- The number of parallel cores (`NP`) in `Allrun.sh` must match `numberOfSubdomains` in `system/decomposeParDict`.
- For detailed technical documentation on governing equations, numerical schemes, PISO algorithm, and mesh strategy, see `docs/technical_details.md`.
