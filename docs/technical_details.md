# OpenFOAM 二维圆柱绕流 CFD 仿真 — 技术文档

本文档详细阐述本项目的物理背景、控制方程、数值方法、网格策略、边界条件设定、求解器配置以及后处理流程，面向具备一定流体力学基础的读者。

---

## 目录

1. [物理问题描述](#1-物理问题描述)
2. [控制方程](#2-控制方程)
3. [无量纲参数体系](#3-无量纲参数体系)
4. [计算域与网格设计](#4-计算域与网格设计)
5. [边界条件设定](#5-边界条件设定)
6. [数值离散格式](#6-数值离散格式)
7. [PISO 压力-速度耦合算法](#7-piso-压力-速度耦合算法)
8. [线性方程组求解器配置](#8-线性方程组求解器配置)
9. [并行计算策略](#9-并行计算策略)
10. [力系数监测与后处理](#10-力系数监测与后处理)
11. [时间步长控制与稳定性](#11-时间步长控制与稳定性)
12. [运行流程总览](#12-运行流程总览)
13. [物理量参考值汇总](#13-物理量参考值汇总)

---

## 1. 物理问题描述

### 1.1 问题背景

二维圆柱绕流是计算流体力学（CFD）中最经典的基准问题之一。当均匀来流绕过一个圆柱体时，在特定雷诺数范围内，尾迹区会产生周期性交替脱落的旋涡，形成著名的**卡门涡街（Kárman Vortex Street）**。

本案例针对 **Re = 100** 的层流工况进行数值模拟。在该雷诺数下，流动呈现二维、层流、周期性涡脱落的特征，是验证 CFD 求解器精度和网格质量的理想基准。

### 1.2 流动特征

| 雷诺数范围 | 流动状态 |
|---|---|
| Re < 5 | 无分离，前后对称 |
| 5 ≤ Re < 40 | 出现固定回流泡（steady recirculation） |
| 40 ≤ Re < 150 | 层流卡门涡街（二维周期性涡脱落）← **本案例** |
| 150 ≤ Re < 300 | 转捩区，三维效应开始出现 |
| Re ≥ 300 | 亚临界湍流状态 |

Re = 100 处于典型的层流涡脱落区间，斯特劳哈尔数（Strouhal number）实验值约为 **St ≈ 0.164**，平均阻力系数约为 **Cd ≈ 1.3–1.5**。

---

## 2. 控制方程

### 2.1 连续性方程（质量守恒）

对于不可压缩流动，密度 ρ 为常数，连续性方程简化为：

$$
\nabla \cdot \mathbf{U} = 0
$$

即速度场的散度为零，表示流体体积守恒。

### 2.2 Navier-Stokes 动量方程

不可压缩牛顿流体的瞬时动量方程（以运动学压力表示）：

$$
\frac{\partial \mathbf{U}}{\partial t} + \nabla \cdot (\mathbf{U} \otimes \mathbf{U}) = -\nabla p + \nu \nabla^2 \mathbf{U}
$$

其中：
- **U**：速度矢量 [m/s]
- **t**：时间 [s]
- **p**：运动学压力（= P/ρ）[m²/s²]，icoFoam 求解的是除以密度后的压力
- **ν**：运动粘度 [m²/s]

方程各项的物理含义：

| 项 | 名称 | 物理意义 |
|---|---|---|
| ∂U/∂t | 局部加速度项 | 速度随时间的变化率 |
| ∇·(U⊗U) | 对流项 | 流体微团携带的动量输运 |
| −∇p | 压力梯度项 | 压力差驱动的流体加速 |
| ν∇²U | 粘性扩散项 | 粘性力引起的动量耗散 |

### 2.3 icoFoam 求解器说明

`icoFoam` 是 OpenFOAM 内置的瞬态不可压缩层流求解器，具有以下特点：
- 直接求解原始变量的 Navier-Stokes 方程
- 采用 **PISO（Pressure-Implicit with Splitting of Operators）** 算法处理压力-速度耦合
- 不引入任何湍流模型（Re = 100 为层流，无需湍流封闭）
- 求解的运动学压力 p = P/ρ，后处理时需乘以密度恢复真实压力

---

## 3. 无量纲参数体系

### 3.1 雷诺数（Reynolds Number）

雷诺数表征惯性力与粘性力的比值：

$$
Re = \frac{U_\infty D}{\nu}
$$

本案例参数反推：

| 参数 | 符号 | 值 |
|---|---|---|
| 来流速度 | U∞ | 34.7188 m/s |
| 圆柱直径 | D | 0.01 m |
| 运动粘度 | ν | 3.47188 × 10⁻³ m²/s |

$$
Re = \frac{34.7188 \times 0.01}{3.47188 \times 10^{-3}} = 100.0
$$

> **设计说明**：本案例采用了"放大速度、放大粘度"的等价策略。物理上真实空气的 ν ≈ 1.5×10⁻⁵ m²/s，若要在 D=0.01m 下达到 Re=100，需要 U≈1.5 m/s，时间尺度较长。将 ν 人为放大到 3.47×10⁻³，同时放大 U 到 34.7 m/s，在保持 Re=100 不变的前提下缩短了物理仿真时间。

### 3.2 阻力系数（Drag Coefficient）

$$
C_d = \frac{F_d}{\frac{1}{2} \rho U_\infty^2 A_{ref}}
$$

其中：
- Fd：圆柱受到的流向（x方向）合力（压差阻力 + 粘性摩擦阻力）
- Aref = D × t = 0.01 × 0.001 = **1×10⁻⁵ m²**（参考面积 = 直径 × 展向厚度）

OpenFOAM `forceCoeffs` 功能对象将其分解为：
- **Cd(f)**：压差（form/pressure）阻力分量
- **Cd(r)**：摩擦（friction/viscous）阻力分量

### 3.3 升力系数（Lift Coefficient）

$$
C_l = \frac{F_l}{\frac{1}{2} \rho U_\infty^2 A_{ref}}
$$

其中 Fl 为横向（y方向）合力。在涡脱落过程中，Cl 呈周期性正弦振荡，幅值约 ±0.3（Re=100）。

### 3.4 斯特劳哈尔数（Strouhal Number）

$$
St = \frac{f_s D}{U_\infty}
$$

其中 fs 为涡脱落频率 [Hz]。St 可通过 Cl 时间序列的 FFT 分析提取。

对于 Re=100，经验公式（Williamson, 1989）给出：

$$
St \approx 0.164
$$

对应涡脱落频率：

$$
f_s = \frac{St \cdot U_\infty}{D} = \frac{0.164 \times 34.7188}{0.01} \approx 569 \text{ Hz}
$$

脱落周期：

$$
T = \frac{1}{f_s} \approx 1.76 \times 10^{-3} \text{ s}
$$

### 3.5 压力系数（Pressure Coefficient）

$$
C_p = \frac{P - P_\infty}{\frac{1}{2} \rho U_\infty^2}
$$

在圆柱表面，理论无粘流（势流）解为 Cp = 1 − 4sin²θ，其中 θ 为从前驻点量起的极角。实际粘性流的 Cp 分布与势流解存在显著偏差，这也是CFD仿真的价值所在。

---

## 4. 计算域与网格设计

### 4.1 计算域尺寸

```
          ←──────── 30D = 0.3 m ────────→
          ┌──────────────────────────────┐  ↑
          │                              │  │
          │         farfield (slip)      │  20D = 0.2 m
          │                              │  ↓
    inlet │     ╭───╮                    │ outlet
   (fixed │ ←── │ D │ ──→ wake zone     │ (pressure
    value) │     ╰───╯                    │  outlet)
          │   10D                        │
          └──────────────────────────────┘
```

| 参数 | 值 | 说明 |
|---|---|---|
| 域宽 Lx | 30D = 0.3 m | 流向长度 |
| 域高 Ly | 20D = 0.2 m | 横向宽度 |
| 展向厚度 | 0.1D = 0.001 m | 单层网格（2D 标准做法） |
| 圆柱中心 | (10D, 0) = (0.1, 0) m | 距入口 10D，保证充分发展 |
| 出口距离 | 20D | 避免出口边界干扰尾迹 |

### 4.2 网格拓扑与分层策略

采用 **Gmsh** 生成混合结构/非结构网格，共分为四个区域：

#### 区域一：圆柱表面边界层（结构化四边形网格）

这是最关键的区域，直接决定壁面力计算精度。

| 参数 | 值 | 说明 |
|---|---|---|
| 外半径 R_bl | R + 0.15D = 6.5 mm | 边界层区域外缘 |
| 圆周方向节点数 | n_circ = 60 | 沿圆周均匀分布 |
| 径向层数 | n_radial = 20 | 从壁面到外缘 |
| 增长率 | 1.05 | 几何级数，壁面最密 |
| 网格类型 | Transfinite + Recombine | 结构化四边形 |

壁面首层网格高度估算：

$$
\Delta y_1 = \frac{R_{bl} - R}{\sum_{i=0}^{n-1} r^i} = \frac{0.0015}{\sum_{i=0}^{19} 1.05^i} \approx \frac{0.0015}{33.07} \approx 4.5 \times 10^{-5} \text{ m}
$$

对应壁面 y+ 估算（基于摩擦速度 uτ）：

$$
y^+ = \frac{u_\tau \Delta y_1}{\nu}
$$

对于 Re=100 的层流，y+ << 1，满足直接解析壁面剪切力的要求。

#### 区域二：尾迹加密区（非结构化三角形网格）

圆柱后方 3D 到 20D、上下各 3D 范围内的矩形区域，网格尺度 lc_wake = 0.1D = 1 mm，用于捕捉脱落旋涡的输运和演化。

#### 区域三：过渡区

BL 外缘圆与尾迹区之间的区域，网格尺度从 lc_bl = 0.1D 平滑过渡到 lc_far = 0.5D。

#### 区域四：远场区

计算域外围区域，网格尺度 lc_far = 0.5D = 5 mm，流场梯度较小，粗网格即可满足精度。

### 4.3 网格统计

| 指标 | 值 |
|---|---|
| 总节点数 | 82,148 |
| 总单元数 | 77,228 |
| 六面体单元 | 4,484（边界层） |
| 楔形单元 | 72,744（三角形挤出） |
| 最大非正交角 | 34.52°（< 70°，合格） |
| 最大偏斜度 | 0.546（合格） |
| 最大纵横比 | 2.67（合格） |

### 4.4 二维网格实现方式

OpenFOAM 原生不支持纯二维网格。本案例采用标准技巧：
1. 在 Gmsh 中将 2D 网格沿 z 方向挤出 0.1D = 0.001 m（单层）
2. 前后两面（frontAndBack）设为 `empty` 类型
3. `empty` 边界条件使该方向的所有梯度为零，等效于二维流动

---

## 5. 边界条件设定

### 5.1 速度场 U

| 边界 | 类型 | 值 | 物理含义 |
|---|---|---|---|
| **inlet** | `fixedValue` | (34.7188, 0, 0) m/s | 均匀来流，固定速度 |
| **outlet** | `pressureInletOutletVelocity` | — | 出口处若为回流则施加零梯度约束，否则自由出流 |
| **farfield** | `slip` | — | 无穿透、无摩擦滑移壁面，模拟无限远场 |
| **cylinder** | `noSlip` | — | 无滑移壁面，U = 0 |
| **frontAndBack** | `empty` | — | 二维对称面 |

`pressureInletOutletVelocity` 的选取原因：出口处可能出现涡脱落引起的局部回流，该边界条件在回流时自动切换为入口约束，避免非物理反射。

### 5.2 压力场 p

| 边界 | 类型 | 值 | 物理含义 |
|---|---|---|---|
| **inlet** | `zeroGradient` | — | 入口压力由内部场外推 |
| **outlet** | `fixedValue` | 362.48 m²/s² | 固定参考压力（= 444.038 Pa / 1.225 kg/m³） |
| **farfield** | `zeroGradient` | — | 远场压力自由 |
| **cylinder** | `zeroGradient` | — | 壁面法向压力梯度为零（Neumann 条件） |
| **frontAndBack** | `empty` | — | 二维对称面 |

压力出口设为 `fixedValue` 而非 `zeroGradient` 的原因：为整个计算域提供唯一的压力参考点，防止压力场出现浮动（pressure drift）。

### 5.3 边界条件相容性

在 OpenFOAM 中，速度与压力的边界条件必须相容：
- **速度固定 → 压力零梯度**（如入口）
- **速度零梯度 → 压力固定**（如出口）
- **壁面无滑移 → 压力零梯度**（由 PISO 动量预测器隐式处理）

本案例的设定严格遵循这一原则。

---

## 6. 数值离散格式

### 6.1 时间离散

```
ddtSchemes
{
    default         backward;
}
```

`backward` 为**二阶向后差分**格式（Second-order Backward Differentiation Formula, BDF2）：

$$
\frac{\partial \phi}{\partial t} \approx \frac{3\phi^{n+1} - 4\phi^n + \phi^{n-1}}{2\Delta t}
$$

相比一阶欧拉格式，BDF2 具有二阶时间精度，显著降低了时间积分的数值耗散，对于捕捉涡脱落等非定常现象至关重要。

### 6.2 梯度离散

```
gradSchemes
{
    default         Gauss linear;
    grad(p)         cellLimited Gauss linear 1;
}
```

- **默认**：基于高斯定理的线性插值梯度重构（二阶精度）
- **压力梯度**：添加 `cellLimited` 限制器，防止压力梯度在激变区域产生非物理振荡，限制系数为 1（最宽松限制）

高斯梯度公式：

$$
(\nabla \phi)_P = \frac{1}{V_P} \sum_f \phi_f \mathbf{S}_f
$$

其中 φf 由相邻单元线性插值得到，Sf 为面积矢量。

### 6.3 对流项离散

```
divSchemes
{
    div(phi,U)      bounded Gauss linearUpwind grad(U);
    div(phi,h)      bounded Gauss linearUpwind grad(h);
    div(phi,K)      bounded Gauss upwind;
    div(phid,p)     bounded Gauss upwind;
    div(((rho*nuEff)*dev2(T(grad(U)))))   Gauss linear;
}
```

| 项 | 格式 | 精度 | 说明 |
|---|---|---|---|
| div(phi,U) | `linearUpwind` | 二阶 | 基于梯度的迎风线性插值，有界性保证 |
| div(phi,K) | `upwind` | 一阶 | 动能对流项，稳定性优先 |
| div(phid,p) | `upwind` | 一阶 | 压力方程对流项 |
| 粘性应力散度 | `linear` | 二阶 | 扩散项天然适合中心差分 |

`linearUpwind` 格式的数学表达：

$$
\phi_f = \phi_U + (\nabla \phi)_U \cdot \mathbf{d}_{Uf}
$$

其中下标 U 表示迎风侧单元，dUf 为从迎风单元中心到面中心的矢量。该格式在迎风方向上引入梯度修正，达到二阶精度，同时通过 `bounded` 关键字确保有界性。

### 6.4 拉普拉斯项与面法向梯度

```
laplacianSchemes
{
    default         Gauss linear corrected;
}

snGradSchemes
{
    default         corrected;
}
```

`corrected` 表示对非正交网格进行显式非正交修正：

$$
(\nabla \phi)_f \cdot \mathbf{S}_f = |\mathbf{S}_f| \frac{\phi_N - \phi_P}{|\mathbf{d}|} + \underbrace{(\nabla \phi)_f \cdot (\mathbf{S}_f - |\mathbf{S}_f|\frac{\mathbf{d}}{|\mathbf{d}|})}_{\text{非正交修正项（显式）}}
$$

第一项为正交近似，第二项利用已有梯度场显式计算修正量，在 `nNonOrthogonalCorrectors = 1` 的设定下迭代修正一次。

---

## 7. PISO 压力-速度耦合算法

### 7.1 算法原理

PISO（Pressure-Implicit with Splitting of Operators）是专为瞬态问题设计的压力-速度耦合算法，每个时间步内执行多次修正循环：

```
给定 U^n, p^n

[1] 动量预测器（Momentum Predictor）：
    用 p^n 求解动量方程，得到预测速度 U*
    
    a_P U_P^* = -\sum_N a_N U_N^* - \nabla p^n + S_U

[2] 压力修正循环（i = 1, 2, ..., nCorrectors）：
    
    (a) 构造通量预测：
        \phi^* = (U^*)_f \cdot S_f
    
    (b) 求解压力泊松方程：
        \nabla \cdot (HbyA) - \nabla \cdot (\frac{1}{a_P} \nabla p^{**}) = 0
        
        其中 HbyA = H(U^*)/a_P，H 算子包含邻点贡献和源项
    
    (c) 修正通量：
        \phi^{**} = \phi^* - (\frac{1}{a_P})_f (\nabla p^{**})_f \cdot S_f
    
    (d) 修正速度：
        U^{**} = HbyA - \frac{1}{a_P} \nabla p^{**}

[3] 更新：U^{n+1} = U^{**}, p^{n+1} = p^{**}
```

### 7.2 本案例配置

```
PISO
{
    nCorrectors                 2;
    nNonOrthogonalCorrectors    1;
    momentumPredictor           yes;
}
```

| 参数 | 值 | 说明 |
|---|---|---|
| nCorrectors | 2 | 每时间步执行 2 次 PISO 修正循环 |
| nNonOrthogonalCorrectors | 1 | 对非正交网格进行 1 次额外修正 |
| momentumPredictor | yes | 启用动量预测器（先求解动量方程再进入 PISO 循环） |

### 7.3 HbyA 分解技术

OpenFOAM 采用 HbyA（H divided by A）分解将动量方程重写为：

$$
\mathbf{U} = \frac{\mathbf{H}(\mathbf{U})}{a_P} - \frac{1}{a_P} \nabla p
$$

其中 aP 为动量方程对角线系数，H(U) 包含所有邻点贡献和显式源项。将其代入连续性方程 ∇·U = 0，得到压力泊松方程：

$$
\nabla \cdot \left(\frac{1}{a_P} \nabla p\right) = \nabla \cdot \left(\frac{\mathbf{H}(\mathbf{U})}{a_P}\right)
$$

这是一个椭圆型偏微分方程，求解后通过梯度修正保证速度场满足连续性约束。

---

## 8. 线性方程组求解器配置

### 8.1 压力方程（椭圆型）

```
p
{
    solver          GAMG;
    tolerance       1e-08;
    relTol          0.01;
    smoother        DICGaussSeidel;
}

pFinal
{
    $p;
    relTol          0;
}
```

**GAMG（Geometric-Algebraic MultiGrid）** 是压力泊松方程的首选求解器：

- **原理**：通过构建多级网格层次，在细网格上消除高频误差，在粗网格上消除低频误差，实现近似 O(N) 的收敛速度
- **平滑器**：DICGaussSeidel（对角不完全 Cholesky 分解 + Gauss-Seidel），兼顾收敛速度与稳定性
- **pFinal**：时间步最后一次 PISO 修正使用更严格的相对容差（relTol = 0），确保最终压力场精确满足连续性方程

### 8.2 动量方程（对流-扩散型）

```
U
{
    solver          PBiCGStab;
    preconditioner  DILU;
    tolerance       1e-08;
    relTol          0.1;
}

UFinal
{
    $U;
    relTol          0;
}
```

**PBiCGStab（Preconditioned Bi-Conjugate Gradient Stabilized）**：
- 适用于非对称矩阵（对流项导致系数矩阵非对称）
- **DILU 预条件器**（Diagonal Incomplete LU）：对系数矩阵进行不完全 LU 分解，加速迭代收敛
- 相对容差 0.1 表示残差降低到初始值的 10% 即满足，因为动量方程在 PISO 循环中会被反复求解

---

## 9. 并行计算策略

### 9.1 域分解

```
numberOfSubdomains  16;
method              scotch;
```

**Scotch** 是基于图划分理论的自动分解方法：

- 将网格单元视为图的节点，相邻关系视为边
- 通过多层递归二分（Multilevel Recursive Bisection）最小化子域间通信面数
- 特别适合非结构网格（本案例含三角形 + 四边形混合单元）

### 9.2 负载均衡统计

| 指标 | 值 |
|---|---|
| 子域数量 | 16 |
| 平均单元数/子域 | 4,826.75 |
| 最大偏差 | 0.81%（极为均衡） |
| 最大通信面数 | 208 |

### 9.3 并行运行方式

```bash
decomposePar -force                          # 分解
mpirun -np 16 icoFoam -parallel              # 并行求解
reconstructPar                               # 重构完整场
```

- `decomposePar` 将完整网格和场数据分配到 processor0 ~ processor15
- `mpirun` 启动 16 个 MPI 进程，通过 Halo Exchange 交换边界数据
- `reconstructPar` 将所有子域数据合并为完整场，用于后处理

---

## 10. 力系数监测与后处理

### 10.1 力计算原理

OpenFOAM `forces` 功能对象在每个 writeInterval 计算圆柱表面（patch: cylinder）上的合力：

$$
\mathbf{F} = \underbrace{\sum_f p_f \mathbf{S}_f}_{\text{压差力（form force）}} + \underbrace{\sum_f (\boldsymbol{\tau}_f \cdot \mathbf{S}_f)}_{\text{粘性力（viscous force）}}
$$

其中：
- pf：面心处的压力
- Sf：面面积矢量（指向流体外部）
- τf：粘性应力张量 = ν(∇U + (∇U)ᵀ)

力矩计算以旋转中心 CofR = (0.1, 0, 0) 为参考点：

$$
\mathbf{M} = \sum_f (\mathbf{r}_f - \mathbf{r}_{CofR}) \times (p_f \mathbf{S}_f + \boldsymbol{\tau}_f \cdot \mathbf{S}_f)
$$

### 10.2 力系数无量纲化

`forceCoeffs` 功能对象将力转换为无量纲系数：

```
magUInf     34.7188;      // 参考速度
lRef        0.01;         // 参考长度 = D
Aref        1e-5;         // 参考面积 = D × thickness
rhoInf      1.225;        // 参考密度
liftDir     (0 1 0);      // 升力方向
dragDir     (1 0 0);      // 阻力方向
```

$$
C_d = \frac{F_x}{\frac{1}{2} \rho U_\infty^2 A_{ref}}, \quad
C_l = \frac{F_y}{\frac{1}{2} \rho U_\infty^2 A_{ref}}, \quad
C_m = \frac{M_z}{\frac{1}{2} \rho U_\infty^2 A_{ref} l_{ref}}
$$

### 10.3 预期结果

仿真至 t = 0.03 s（约 17 个脱落周期）后，预期：

| 物理量 | 预期值 | 实验参考 |
|---|---|---|
| 平均阻力系数 Cd | ~1.35–1.45 | 1.30–1.50 |
| 升力系数幅值 Cl_max | ~0.25–0.35 | ~0.30 |
| 斯特劳哈尔数 St | ~0.160–0.170 | ~0.164 |

### 10.4 数据后处理流程

原始 `coefficient.dat` 包含空格分隔的多列数据和 `#` 注释行。Python 脚本 `scripts/standardize_force_coeffs_csv.py` 将其转换为标准 CSV：

```
Time,Cd,Cd(f),Cd(r),Cl,Cl(f),Cl(r),CmPitch,CmRoll,CmYaw,Cs,Cs(f),Cs(r)
```

便于后续用 pandas/matplotlib 进行时间序列分析和频谱分析。

---

## 11. 时间步长控制与稳定性

### 11.1 CFL 条件

Courant-Friedrichs-Lewy (CFL) 数是显式/半显式时间推进的稳定性准则：

$$
Co = \frac{|\mathbf{U}| \Delta t}{\Delta x} \leq Co_{max}
$$

本案例设置：

```
adjustTimeStep    yes;
maxCo             1.0;
maxDeltaT         1e-4;
deltaT            1e-6;        // 初始时间步
```

- 时间步长在每个时间步自动调整，确保全局最大 Co ≤ 1.0
- 上限 maxDeltaT = 1×10⁻⁴ s 防止时间步过大跳过物理时间尺度
- 初始 deltaT = 1×10⁻⁶ s 用于仿真启动阶段（流场尚未建立，速度梯度较大）

### 11.2 时间步长与涡脱落周期的关系

$$
\frac{T_{shedding}}{\Delta t_{max}} = \frac{1.76 \times 10^{-3}}{1 \times 10^{-4}} \approx 17.6
$$

每个脱落周期至少 17 个时间步，结合二阶 backward 格式，时间分辨率满足工程精度要求。实际运行时由于 Co ≤ 1 的约束，多数时间步远小于 maxDeltaT，分辨率更高。

---

## 12. 运行流程总览

`Allrun.sh` 定义了完整的仿真流水线：

```
[1] gmshToFoam          将 Gmsh .msh 转换为 OpenFOAM polyMesh 格式
        ↓
[2] foamDictionary      修正边界类型（frontAndBack → empty, cylinder → wall）
        ↓
[3] checkMesh           检查网格质量（非正交、偏斜度、纵横比等）
        ↓
[4] decomposePar        将网格和场分解为 16 个子域
        ↓
[5] icoFoam -parallel   16核并行瞬态求解（t = 0 → 0.03 s）
        ↓
[6] reconstructPar      合并子域数据为完整场
        ↓
[7] 清理 processor*/    删除中间并行文件
```

---

## 13. 物理量参考值汇总

| 物理量 | 符号 | 值 | 单位 |
|---|---|---|---|
| 圆柱直径 | D | 0.01 | m |
| 圆柱半径 | R | 0.005 | m |
| 来流速度 | U∞ | 34.7188 | m/s |
| 运动粘度 | ν | 3.47188 × 10⁻³ | m²/s |
| 动力粘度 | μ = ρν | 4.253 × 10⁻³ | Pa·s |
| 密度 | ρ | 1.225 | kg/m³ |
| 雷诺数 | Re | 100 | — |
| 参考面积 | Aref | 1 × 10⁻⁵ | m² |
| 参考长度 | lref | 0.01 | m |
| 域尺寸 | Lx × Ly × Lz | 0.3 × 0.2 × 0.001 | m |
| 域宽比 | Lx/D × Ly/D | 30 × 20 | — |
| 阻塞率 | D/Ly | 5% | — |
| 仿真时间 | t_end | 0.03 | s |
| 输出帧数 | — | 300 | 帧 |
| 输出间隔 | Δt_write | 1 × 10⁻⁴ | s |
| 总网格单元 | N_cells | 77,228 | — |
| 并行核数 | NP | 16 | — |
| 求解器 | — | icoFoam | — |
| 湍流模型 | — | 无（层流） | — |

---

## 参考文献

1. **Williamson, C.H.K.** (1989). "Oblique and parallel modes of vortex shedding in the wake of a circular cylinder at low Reynolds numbers." *Journal of Fluid Mechanics*, 206, 579-627.
2. **Tritton, D.J.** (1959). "Experiments on the flow past a circular cylinder at low Reynolds numbers." *Journal of Fluid Mechanics*, 6(4), 547-567.
3. **Issa, R.I.** (1986). "Solution of the implicitly discretised fluid flow equations by operator-splitting." *Journal of Computational Physics*, 62(1), 40-65. (PISO 算法原始论文)
4. **OpenFOAM Foundation**. *The OpenFOAM User Guide*. https://www.openfoam.com/documentation
5. **Ferziger, J.H. & Perić, M.** (2002). *Computational Methods for Fluid Dynamics*. 3rd Edition, Springer.
