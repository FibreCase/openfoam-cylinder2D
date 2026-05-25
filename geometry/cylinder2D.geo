// ============================================================
//  圆柱绕流 2D — 混合网格
//  O形边界层（0~0.3D，结构化四边形）+ 远场三角形
//  Re = 100, D = 1m
// ============================================================

D   = 1;
R   = D / 2;            // 0.5
x0  = 5 * D;
y0  = 0;
Lx  = 20 * D;
Ly  = 10 * D;

lc_far = D * 0.15;      // 远场网格尺寸
lc_cyl = D * 0.015;     // 圆柱面网格尺寸
lc_bl  = D * 0.04;      // 边界层外圆尺寸

R_bl = R + 0.15 * D;     // 边界层外圆半径 = 0.65D

// ==================== 点定义 ====================

// 矩形四角
Point(1) = {0,   -Ly/2, 0, lc_far};
Point(2) = {Lx,  -Ly/2, 0, lc_far};
Point(3) = {Lx,   Ly/2, 0, lc_far};
Point(4) = {0,    Ly/2, 0, lc_far};

// 圆柱：圆心 + 四极点
Point(5) = {x0,       y0,     0, lc_cyl};  // 圆心（仅供圆弧用）
Point(6) = {x0 + R,   y0,     0, lc_cyl};  // 0°
Point(7) = {x0,       y0 + R, 0, lc_cyl};  // 90°
Point(8) = {x0 - R,   y0,     0, lc_cyl};  // 180°
Point(9) = {x0,       y0 - R, 0, lc_cyl};  // 270°

// 边界层外圆四极点
Point(10) = {x0 + R_bl, y0,        0, lc_bl};
Point(11) = {x0,        y0 + R_bl, 0, lc_bl};
Point(12) = {x0 - R_bl, y0,        0, lc_bl};
Point(13) = {x0,        y0 - R_bl, 0, lc_bl};

// ==================== 线定义 ====================

// 矩形外边界
Line(1) = {1, 2};   // 底边
Line(2) = {2, 3};   // 出口
Line(3) = {3, 4};   // 顶边
Line(4) = {4, 1};   // 入口

// 圆柱内圆弧（逆时针，4×90°）
Circle(5) = {6, 5, 7};   //   0° →  90°
Circle(6) = {7, 5, 8};   //  90° → 180°
Circle(7) = {8, 5, 9};   // 180° → 270°
Circle(8) = {9, 5, 6};   // 270° → 360°

// 边界层外圆弧（逆时针，4×90°）
Circle(9)  = {10, 5, 11};
Circle(10) = {11, 5, 12};
Circle(11) = {12, 5, 13};
Circle(12) = {13, 5, 10};

// 径向连接线（内圆 → 外圆）
Line(13) = {6, 10};
Line(14) = {7, 11};
Line(15) = {8, 12};
Line(16) = {9, 13};

// ==================== 边界层四个扇形面 ====================

Curve Loop(1) = {5,  14, -9,  -13};   Plane Surface(1) = {1};
Curve Loop(2) = {6,  15, -10, -14};   Plane Surface(2) = {2};
Curve Loop(3) = {7,  16, -11, -15};   Plane Surface(3) = {3};
Curve Loop(4) = {8,  13, -12, -16};   Plane Surface(4) = {4};

// ==================== Transfinite 结构化控制 ====================

n_circ   = 60;    // 每象限圆周方向节点数（总周向 4×60=240）
n_radial = 20;    // 径向节点数（含两端）
prog     = 1.05;  // 径向增长率，贴壁侧加密

// 圆柱面弧与边界层外弧：节点数一致
Transfinite Curve{5, 6, 7, 8}     = n_circ   Using Progression 1;
Transfinite Curve{9, 10, 11, 12}  = n_circ   Using Progression 1;

// 径向线：从圆柱面向外增长
Transfinite Curve{13, 14, 15, 16} = n_radial Using Progression prog;

// 指定各扇形的四角点（顺序：沿环一圈）
Transfinite Surface{1} = {6,  7,  11, 10};
Transfinite Surface{2} = {7,  8,  12, 11};
Transfinite Surface{3} = {8,  9,  13, 12};
Transfinite Surface{4} = {9,  6,  10, 13};

// 将四边形重组为纯四边形单元（Recombine）
Recombine Surface{1, 2, 3, 4};

// ==================== 远场三角形区域 ====================

Curve Loop(5) = {1, 2, 3, 4};       // 矩形外边界
Curve Loop(6) = {9, 10, 11, 12};    // 边界层外圆（作为孔）
Plane Surface(5) = {5, 6};          // 矩形域 − 边界层圆 = 三角形区域

// 注意：Surface(5) 不加 Transfinite/Recombine，Gmsh 默认生成三角形

// ==================== Z方向拉伸（OpenFOAM 2D）====================

thickness = 0.1 * D;

// 分别拉伸，方便后续追踪面编号
ext_bl1[] = Extrude {0, 0, thickness} { Surface{1}; Layers{1}; Recombine; };
ext_bl2[] = Extrude {0, 0, thickness} { Surface{2}; Layers{1}; Recombine; };
ext_bl3[] = Extrude {0, 0, thickness} { Surface{3}; Layers{1}; Recombine; };
ext_bl4[] = Extrude {0, 0, thickness} { Surface{4}; Layers{1}; Recombine; };
ext_ff[]  = Extrude {0, 0, thickness} { Surface{5}; Layers{1}; Recombine; };

// ==================== Physical Groups ====================
// Extrude 返回值结构：
//   ext[0]  = 顶面 (top surface)
//   ext[1]  = 第1条边界线拉伸成的侧面
//   ext[2]  = 第2条...  依此类推（顺序与 Curve Loop 中线的顺序一致）
//
// 边界层扇形面 Curve Loop 顺序（以扇形1为例）：
//   {5, 14, -9, -13} → 侧面依次为：
//     ext_bl1[2] = 圆弧5拉伸（圆柱面，象限1）
//     ext_bl1[3] = 线14拉伸（径向侧面）
//     ext_bl1[4] = 弧9拉伸（边界层外圆面，象限1）
//     ext_bl1[5] = 线13拉伸（径向侧面）
//
// 远场面 Curve Loop 顺序：{1,2,3,4} 对应 ext_ff[2..5]
//   ext_ff[2] = Line(1)底边拉伸 → bottom/wall
//   ext_ff[3] = Line(2)出口拉伸 → outlet
//   ext_ff[4] = Line(3)顶边拉伸 → top/wall
//   ext_ff[5] = Line(4)入口拉伸 → inlet
//   （外圆部分由 ext_ff[6..9] 给出，属内部边界，不作 Physical）

Physical Surface("inlet") = {ext_ff[5]};
Physical Surface("outlet") = {ext_ff[3]};
Physical Surface("walls") = {
    ext_ff[2], ext_ff[4],  // 上下壁面
    ext_bl1[2],   // 圆弧5（0°~90°）
    ext_bl2[2],   // 圆弧6（90°~180°）
    ext_bl3[2],   // 圆弧7（180°~270°）
    ext_bl4[2]    // 圆弧8（270°~360°）
};

Physical Surface("frontAndBack") = {
    1, 2, 3, 4, 5,               // 原始 z=0 面
    ext_bl1[0], ext_bl2[0],
    ext_bl3[0], ext_bl4[0],
    ext_ff[0]                    // 拉伸后的 z=thickness 面
};

Physical Volume("fluid") = {
    ext_bl1[1], ext_bl2[1],
    ext_bl3[1], ext_bl4[1],
    ext_ff[1]
};

// ==================== 网格算法 ====================
// 远场用 Delaunay 三角形，边界层已由 Transfinite 控制
Mesh.Algorithm = 5;            // Delaunay（适合混合网格）
Mesh.RecombinationAlgorithm = 1;
Mesh.CharacteristicLengthMin = lc_cyl;
Mesh.CharacteristicLengthMax = lc_far;