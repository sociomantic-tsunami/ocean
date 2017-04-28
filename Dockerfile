FROM sociomantictsunami/dlang:v1-trusty
COPY docker/ /docker-tmp
RUN /docker-tmp/build && rm -fr /docker-tmp
