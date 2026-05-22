# 由于原镜像使用root账户计算，可能带来权限问题，故在此基础上创建一个新的镜像，使用非root用户进行计算。
FROM opencfd/openfoam-run:latest

# 设置工作目录和权限
RUN mkdir -p /workspace && chown -R 1000:1000 /workspace
WORKDIR /workspace

# 切换到非root用户
USER 1000:1000