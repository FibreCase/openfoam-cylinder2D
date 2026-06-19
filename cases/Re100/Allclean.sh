#!/bin/bash
log() { echo "[$(date '+%H:%M:%S')] $*"; }

# ---- 1. 清理 processor 目录 ----
rm -rf processor*/

# ---- 2. 清理时间步目录 ----
rm -rf [1-9][0-9]*/
rm -rf [0-9]*.[0-9]*/

# ---- 3. 清理其他生成的文件 ----
rm -rf postProcessing/

# ---- 4. 清理日志文件 ----
rm -f logs/*

log "Done. 已完成结果的清理。"