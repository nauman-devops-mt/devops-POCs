FROM alpine:3.19

LABEL maintainer="nauman-devops-mt"
LABEL org.opencontainers.image.source="https://github.com/nauman-devops-mt/devops-POCs"

ARG VERSION=unknown
LABEL version="${VERSION}"

CMD ["echo", "devops-POCs image"]
