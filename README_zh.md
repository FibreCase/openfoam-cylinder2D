# OpenFOAM 圆柱绕流卡门涡街仿真

本项目基于 OpenFOAM 8，模拟二维圆柱绕流在一定雷诺数下形成的卡门涡街。几何建模与网格生成使用 Gmsh，流场求解使用 `icoFoam`，结果后处理使用 ParaView。

## 项目说明

- 圆柱直径：$D = 0.01\,\text{m}$
- 流体密度：$\rho = 1.225\,\text{kg/m}^3$
- 来流速度：$U = 34.7188\,\text{m/s}$
- 雷诺数：$Re = 100$
- 远场表压：$p_{\infty} = 444.038\,\text{Pa}$
- 计算类型：二维外流
- 几何与网格：Gmsh
- 数值求解：OpenFOAM 8（`icoFoam`，层流，瞬态，PISO 算法）
- 后处理：ParaView

当前仓库中包含以下主要内容：

- `geometry/`：圆柱绕流几何与网格生成脚本
- `cases/Re100/`：Re = 100 工况的 OpenFOAM 算例
- `scripts/`：辅助脚本（力系数 CSV 后处理等）
- `docs/`：技术文档，包含控制方程、数值格式、求解器原理等详细说明

## 工作流

1. 使用 `geometry/cylinder2D.geo` 定义二维圆柱绕流计算域。
2. 使用 `geometry/generate.sh` 调用 Gmsh 生成网格文件（msh2 格式，兼容 OpenFOAM 8）。
3. 在 `cases/Re100/` 下运行 `Allrun.sh`，脚本自动完成网格转换、边界修补、网格检查、并行分解、求解和结果重构。
4. 使用 ParaView 查看速度场、压力场以及涡街演化过程。

## 运行环境

项目通过 Docker 运行 OpenFOAM 8，使用 `openfoam/openfoam8-paraview56:latest` 镜像。提供 VS Code 任务一键启动容器。

### 前置条件

- Docker
- Visual Studio Code

### 启动容器

在 VS Code 中打开命令面板（`Ctrl+Shift+P`），执行：

> **Tasks: Run Task** → **OpenFOAM Terminal**

这会在 OpenFOAM 8 容器中启动一个交互式终端，项目目录挂载到 `/workspace`。容器以 `--user 1000:1000` 运行，保证生成文件的归属与宿主机用户一致。

也可以手动启动容器：

```bash
docker run -it --rm --user 1000:1000 -v .:/workspace openfoam/openfoam8-paraview56:latest
```

## 使用步骤

### 1. 生成网格

```bash
cd geometry
bash generate.sh
```

网格文件默认生成在 `geometry/cylinder2D.msh`。脚本显式使用 Gmsh 的 msh2 格式（`-format msh2`），这是 OpenFOAM 8 的 `gmshToFoam` 所要求的格式。

### 2. 运行算例

```bash
cd cases/Re100
bash Allrun.sh
```

脚本会自动执行以下步骤：

1. 将 Gmsh 网格转换为 OpenFOAM 格式（`gmshToFoam`）
2. 通过 `foamDictionary` 修补边界类型（`frontAndBack → empty`，`cylinder → wall`）
3. 检查网格质量（`checkMesh`）
4. 分解计算域以进行并行计算（`decomposePar`，16 核，scotch 方法）
5. 并行求解（`mpirun -np 16 icoFoam -parallel`）
6. 重构完整流场（`reconstructPar`）
7. 清理 `processor*/` 目录

`gmshToFoam` 转换和边界修补后，`constant/polyMesh/boundary` 文件内容如下：

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

### 3. 后处理

求解完成后，可使用 ParaView 打开案例目录，观察速度云图、压力云图、涡量分布和尾流振荡过程。力系数数据写入 `postProcessing/forceCoeffs/0/coefficient.dat`。

## 目录结构

```text
.
├── geometry/          # Gmsh .geo 文件和 generate.sh
├── cases/Re100/       # OpenFOAM 算例（0/、constant/、system/、Allrun.sh）
├── scripts/           # 后处理工具脚本
├── docs/              # 技术文档
└── .vscode/           # VS Code 容器启动任务
```

## 备注

- 该项目的目标是复现圆柱绕流在 $Re = 100$ 下的涡脱落特征。
- 若需要调整雷诺数、网格密度或域尺寸，可优先修改 `geometry/cylinder2D.geo` 和对应的 OpenFOAM 物理参数设置。
- `Allrun.sh` 中的并行核数（`NP`）须与 `system/decomposeParDict` 中的 `numberOfSubdomains` 保持一致。
- 关于控制方程、数值离散格式、PISO 算法、网格策略等详细技术说明，请参阅 `docs/technical_details.md`。
