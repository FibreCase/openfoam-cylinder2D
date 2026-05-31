// ============================================================
//  圆柱绕流 2D — 混合网格（含尾流加密矩形区）
//  O形边界层（结构化四边形）+ 尾流矩形精细三角形 + 远场粗三角形
//  Re = 100, D = 0.1m
// ============================================================

D   = 0.1;
R   = D / 2;
x0  = 10 * D;
y0  = 0;
Lx  = 30 * D;
Ly  = 20 * D;

lc_far  = D * 0.5;    // 远场粗网格
lc_cyl  = D * 0.05;   // 圆柱面
lc_bl   = D * 0.1;    // BL 外圆
lc_wake = D * 0.1;    // 尾流加密区

R_bl = R + 0.15 * D;   // BL 外圆半径 = 0.65D

// ===== 尾流矩形几何参数 =====
x_wake_min = x0 - 3 * D;    //  2.0  （圆柱前 3D）
x_wake_max = Lx - D;    // 18.0  （出口前留 D 缓冲）
y_wake_min = -3 * D;         // ±3D 即高度 6D
y_wake_max =  3 * D;

// ==================== 点定义 ====================

// 域外矩形四角
Point(1) = {0,   -Ly/2, 0, lc_far};
Point(2) = {Lx,  -Ly/2, 0, lc_far};
Point(3) = {Lx,   Ly/2, 0, lc_far};
Point(4) = {0,    Ly/2, 0, lc_far};

// 圆柱：圆心 + 四极点
Point(5) = {x0,       y0,     0, lc_cyl};
Point(6) = {x0 + R,   y0,     0, lc_cyl};
Point(7) = {x0,       y0 + R, 0, lc_cyl};
Point(8) = {x0 - R,   y0,     0, lc_cyl};
Point(9) = {x0,       y0 - R, 0, lc_cyl};

// BL 外圆四极点
Point(10) = {x0 + R_bl, y0,        0, lc_bl};
Point(11) = {x0,        y0 + R_bl, 0, lc_bl};
Point(12) = {x0 - R_bl, y0,        0, lc_bl};
Point(13) = {x0,        y0 - R_bl, 0, lc_bl};

// 尾流矩形四角（逆时针）
Point(20) = {x_wake_min, y_wake_min, 0, lc_wake};
Point(21) = {x_wake_max, y_wake_min, 0, lc_wake};
Point(22) = {x_wake_max, y_wake_max, 0, lc_wake};
Point(23) = {x_wake_min, y_wake_max, 0, lc_wake};

// ==================== 线定义 ====================

// 域外矩形
Line(1) = {1, 2};    // 底边
Line(2) = {2, 3};    // 出口
Line(3) = {3, 4};    // 顶边
Line(4) = {4, 1};    // 入口

// 圆柱弧（逆时针，4×90°）
Circle(5) = {6, 5, 7};
Circle(6) = {7, 5, 8};
Circle(7) = {8, 5, 9};
Circle(8) = {9, 5, 6};

// BL 外圆弧（逆时针，4×90°）
Circle(9)  = {10, 5, 11};
Circle(10) = {11, 5, 12};
Circle(11) = {12, 5, 13};
Circle(12) = {13, 5, 10};

// 径向连接线（圆柱面 → BL 外圆）
Line(13) = {6, 10};
Line(14) = {7, 11};
Line(15) = {8, 12};
Line(16) = {9, 13};

// 尾流矩形四边（逆时针）
Line(17) = {20, 21};    // 底
Line(18) = {21, 22};    // 右
Line(19) = {22, 23};    // 顶
Line(20) = {23, 20};    // 左

// ==================== BL 四扇形面（结构化四边形）====================

Curve Loop(1) = {5,  14, -9,  -13};   Plane Surface(1) = {1};
Curve Loop(2) = {6,  15, -10, -14};   Plane Surface(2) = {2};
Curve Loop(3) = {7,  16, -11, -15};   Plane Surface(3) = {3};
Curve Loop(4) = {8,  13, -12, -16};   Plane Surface(4) = {4};

// ==================== Transfinite 结构化控制 ====================

n_circ   = 60;
n_radial = 20;
prog     = 1.05;

Transfinite Curve{5, 6, 7, 8}     = n_circ   Using Progression 1;
Transfinite Curve{9, 10, 11, 12}  = n_circ   Using Progression 1;
Transfinite Curve{13, 14, 15, 16} = n_radial Using Progression prog;

Transfinite Surface{1} = {6,  7,  11, 10};
Transfinite Surface{2} = {7,  8,  12, 11};
Transfinite Surface{3} = {8,  9,  13, 12};
Transfinite Surface{4} = {9,  6,  10, 13};

Recombine Surface{1, 2, 3, 4};

// ==================== 远场 + 尾流区（两个独立面）====================

Curve Loop(5) = {1, 2, 3, 4};        // 域外矩形（外边界）
Curve Loop(6) = {9, 10, 11, 12};     // BL 外圆（孔）
Curve Loop(7) = {17, 18, 19, 20};    // 尾流矩形

// Surface(5)：域矩形 − 尾流矩形 → 远场粗网格（三角形，无 Transfinite）
Plane Surface(5) = {5, 7};

// Surface(6)：尾流矩形 − BL 外圆 → 尾流精细三角形
Plane Surface(6) = {7, 6};

// ==================== Z 方向拉伸（OpenFOAM 2D，1 层）====================

thickness = 0.1 * D;

ext_bl1[]   = Extrude {0, 0, thickness} { Surface{1}; Layers{1}; Recombine; };
ext_bl2[]   = Extrude {0, 0, thickness} { Surface{2}; Layers{1}; Recombine; };
ext_bl3[]   = Extrude {0, 0, thickness} { Surface{3}; Layers{1}; Recombine; };
ext_bl4[]   = Extrude {0, 0, thickness} { Surface{4}; Layers{1}; Recombine; };
ext_outer[] = Extrude {0, 0, thickness} { Surface{5}; Layers{1}; Recombine; };
ext_wake[]  = Extrude {0, 0, thickness} { Surface{6}; Layers{1}; Recombine; };

// ==================== Physical Groups ====================
//
// Surface(5) 的 Curve Loop 顺序：{5,7} → 外边界 {1,2,3,4}，孔 {17,18,19,20}
// ext_outer 侧面编号（顺序与 Curve Loop 定义一致）：
//   ext_outer[2] = Line(1) 底边 → walls
//   ext_outer[3] = Line(2) 出口 → outlet
//   ext_outer[4] = Line(3) 顶边 → walls
//   ext_outer[5] = Line(4) 入口 → inlet
//   ext_outer[6..9] = 尾流矩形四边（内部界面，不加 Physical）

Physical Surface("inlet")  = {ext_outer[5]};
Physical Surface("outlet") = {ext_outer[3]};

Physical Surface("walls") = {
    ext_outer[2], ext_outer[4],    // 上下壁面
    ext_bl1[2], ext_bl2[2],
    ext_bl3[2], ext_bl4[2]         // 圆柱面四象限
};

Physical Surface("frontAndBack") = {
    1, 2, 3, 4, 5, 6,              // z = 0 原始面
    ext_bl1[0], ext_bl2[0],
    ext_bl3[0], ext_bl4[0],
    ext_outer[0], ext_wake[0]      // z = thickness 面
};

Physical Volume("fluid") = {
    ext_bl1[1], ext_bl2[1],
    ext_bl3[1], ext_bl4[1],
    ext_outer[1], ext_wake[1]
};

// ==================== 网格算法 ====================
Mesh.Algorithm = 5;
Mesh.RecombinationAlgorithm = 1;
Mesh.CharacteristicLengthMin = lc_cyl;
Mesh.CharacteristicLengthMax = lc_far;