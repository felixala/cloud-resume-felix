FROM nginx:alpine

# The production workflow injects this value before uploading to S3.
# For a local Docker build, provide it with --build-arg.
ARG LAMBDA_FUNCTION_URL=__LAMBDA_FUNCTION_URL__

COPY website/ /usr/share/nginx/html/

RUN test -f /usr/share/nginx/html/index.html \
    && sed -i "s|__LAMBDA_FUNCTION_URL__|${LAMBDA_FUNCTION_URL}|g" \
       /usr/share/nginx/html/index.html

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://127.0.0.1/ >/dev/null || exit 1

CMD ["nginx", "-g", "daemon off;"]
