#!/bin/bash
set -e
cd "$(dirname "$0")"
mkdir -p logs

# ================================================================
# 配置区 —— 按需修改
# ================================================================
MESH_FILE="cylinder.msh"
NP=24
# ================================================================

log() { echo "[$(date '+%H:%M:%S')] $*"; }

# # ---- 1. 转换 GMSH 网格 ----
# log "Converting GMSH mesh..."
# gmshToFoam "$MESH_FILE" > logs/gmshToFoam.log 2>&1

# # ---- 2. 修正 frontAndBack 为 empty（2D）----
# log "Patching frontAndBack → empty..."
# foamDictionary constant/polyMesh/boundary \
#     -entry entry0/frontAndBack/type -set empty >> logs/gmshToFoam.log 2>&1

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