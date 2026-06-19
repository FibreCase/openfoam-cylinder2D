#!/bin/bash
set -e
cd "$(dirname "$0")"
mkdir -p logs

# ================================================================
# 配置区 —— 按需修改
# ================================================================
MESH_FILE="../../geometry/cylinder2D.msh"
NP=16
# ================================================================

log() { echo "[$(date '+%H:%M:%S')] $*"; }

# 几何已改动（patch: walls → farfield + cylinder），必须重新生成网格并转换

# ---- 1. 转换 GMSH 网格 ----
log "Converting GMSH mesh..."
gmshToFoam "$MESH_FILE" > logs/gmshToFoam.log 2>&1

# ---- 2. 修正边界类型（gmshToFoam 默认全为 patch）----
log "Patching boundary types (frontAndBack→empty, cylinder→wall)..."
foamDictionary constant/polyMesh/boundary \
    -entry entry0/frontAndBack/type -set empty >> logs/gmshToFoam.log 2>&1
foamDictionary constant/polyMesh/boundary \
    -entry entry0/cylinder/type -set wall >> logs/gmshToFoam.log 2>&1
# inlet / outlet / farfield 保持 patch（gmshToFoam 默认即为 patch，无需修改）

# ---- 3. 检查网格 ----
log "Checking mesh..."
checkMesh > logs/checkMesh.log 2>&1
grep -E 'Max non-orthogonality|Max skewness|cells' logs/checkMesh.log | tail -5

# ---- 4. 分解网格 ----
log "Decomposing domain into $NP partitions..."
decomposePar -force > logs/decomposePar.log 2>&1

# ---- 5. 并行求解 ----
log "Running icoFoam on $NP cores..."
mpirun -np "$NP" icoFoam -parallel > logs/icoFoam.log 2>&1

# ---- 6. 重组结果 ----
log "Reconstructing fields..."
reconstructPar > logs/reconstructPar.log 2>&1

# ---- 7. （可选）清理 processor 目录 ----
rm -rf processor*/

log "Done. 后处理: paraFoam 或 foamToVTK"