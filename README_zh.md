# OpenFOAM 圆柱绕流卡门涡街仿真

本项目基于 OpenFOAM，模拟二维圆柱绕流在一定雷诺数下形成的卡门涡街。几何建模与网格生成使用 Gmsh，流场求解使用 OpenFOAM，结果后处理使用 ParaView。

## 项目说明

- 圆柱直径：$D = 1\,\text{m}$
- 计算类型：二维外流
- 几何与网格：Gmsh
- 数值求解：OpenFOAM
- 后处理：ParaView

当前仓库中包含以下主要内容：

- `geometry/`：圆柱绕流几何与网格生成脚本
- `cases/Re100/`：Re = 100 工况的 OpenFOAM 算例
- `results/`：结果输出目录
- `scripts/`：辅助脚本目录

## 工作流

1. 使用 `geometry/cylinder2D.geo` 定义二维圆柱绕流计算域。
2. 使用 `geometry/generate.sh` 调用 Gmsh 生成网格文件。
3. 在 `cases/Re100/` 下进行网格检查、并行分解和 OpenFOAM 求解。
4. 使用 ParaView 查看速度场、压力场以及涡街演化过程。

## 运行环境

项目通过 Docker 运行 OpenFOAM，相关配置见 `Dockerfile` 和 `docker-compose.yaml`。

### 启动容器

```bash
docker compose up -d --build
docker exec -it openfoam-runtime bash
```

## 使用步骤

### 1. 生成网格

```bash
cd geometry
bash generate.sh
```

网格文件默认生成在 `geometry/cylinder2D.msh`。

### 2. 运行算例

进入 `cases/Re100/` 后执行 `Allrun.sh`，脚本会完成网格检查、并行分解、求解和重构结果等流程。

> 注意：求解脚本中的网格文件名需要与几何脚本生成的网格文件保持一致。

### 3. 后处理

求解完成后，可使用 ParaView 打开案例目录，观察速度云图、压力云图、涡量分布和尾流振荡过程。

## 目录结构

```text
.
├── Dockerfile
├── docker-compose.yaml
├── geometry/
├── cases/
├── results/
└── scripts/
```

## 备注

- 该项目的目标是复现圆柱绕流的涡脱落特征。
- 若需要调整雷诺数、网格密度或域尺寸，可优先修改 `geometry/cylinder2D.geo` 和对应的 OpenFOAM 物理参数设置。
