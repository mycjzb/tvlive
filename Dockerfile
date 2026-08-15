# TVLive 源站（cms-pub）
# 二进制放镜像内；配置/SQLite 放 /data。Linux 服务器推荐 compose 用 host 网络。
FROM debian:bookworm-slim
RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates tzdata \
  && rm -rf /var/lib/apt/lists/* \
  && ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
COPY cms-pub /usr/local/bin/cms-pub
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/cms-pub /usr/local/bin/docker-entrypoint.sh
WORKDIR /data
EXPOSE 8900 9177 9188
VOLUME ["/data"]
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
